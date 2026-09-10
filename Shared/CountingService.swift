import Foundation
import SwiftData

/// カウントの読み書き。本体・ウィジェット拡張の双方から使う。
///
/// ウィジェット拡張はメモリ制限が厳しいので、当日分（と直近7日分）だけを取り、
/// 全履歴は読まない。
enum CountingService {

    static func startOfDay(_ date: Date = .now) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// 日付が変わる瞬間。ウィジェットの Timeline はここにエントリを置く。
    static func nextMidnight(after date: Date = .now) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay(date)) ?? date.addingTimeInterval(86_400)
    }

    static func counters(in context: ModelContext) throws -> [CounterItem] {
        var descriptor = FetchDescriptor<CounterItem>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        descriptor.relationshipKeyPathsForPrefetching = []
        return try context.fetch(descriptor)
    }

    /// 当日分の記録を項目ごとに合計する。
    static func todayTotals(in context: ModelContext, now: Date = .now) throws -> [UUID: Int] {
        let start = startOfDay(now)
        let end = nextMidnight(after: now)
        let descriptor = FetchDescriptor<CountEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end }
        )
        return try context.fetch(descriptor).reduce(into: [:]) { totals, entry in
            guard let id = entry.counter?.id else { return }
            totals[id, default: 0] += entry.amount
        }
    }

    // MARK: - 週単位の履歴

    /// 詳細画面が一度に見せる1週間。offset 0 が「今日を含む直近7日」で、
    /// 1 増えるごとに7日ずつ古くなる。カレンダー週にしないのは、今週が常に
    /// 途中で切れた棒グラフになって「最近どれくらい押しているか」が読めなくなるため。
    /// end は含まない。
    static func weekWindow(offset: Int, now: Date = .now) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = startOfDay(now)
        let start = calendar.date(byAdding: .day, value: -(6 + offset * 7), to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? today
        return (start, end)
    }

    /// その日が offset いくつの週に入るか。今日を含む週が 0。
    static func weekOffset(containing date: Date, now: Date = .now) -> Int {
        let days = Calendar.current.dateComponents(
            [.day], from: startOfDay(date), to: startOfDay(now)
        ).day ?? 0
        return max(0, days / 7)
    }

    /// 指定した期間の記録だけを取る。
    /// `counter.entries` をたどると全期間が読み込まれるので、履歴表示では必ずこちらを使う。
    static func entries(
        counterID: UUID, in context: ModelContext, from start: Date, to end: Date
    ) throws -> [CountEntry] {
        let descriptor = FetchDescriptor<CountEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        // 期間で絞ったあとに項目で選り分ける。関係に述語を掛けるより素直で、
        // 7日分なら他項目の記録を含めても十分小さい。
        return try context.fetch(descriptor).filter { $0.counter?.id == counterID }
    }

    /// 期間内の記録を日別に合計して古い順に返す。記録が無い日は 0 で埋める。
    static func dayTotals(
        _ entries: [CountEntry], window: (start: Date, end: Date)
    ) -> [(date: Date, total: Int)] {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: window.start, to: window.end).day ?? 7
        let buckets = entries.reduce(into: [Date: Int]()) { totals, entry in
            totals[startOfDay(entry.timestamp), default: 0] += entry.amount
        }
        return (0..<days).compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: index, to: window.start) else { return nil }
            return (day, buckets[day] ?? 0)
        }
    }

    /// 記録のある隣の週の offset。無ければ nil（＝そちら側の端）。
    /// 記録が1件も無い週は飛ばす。空の週を延々と送らせないため。
    static func adjacentWeekOffset(
        counterID: UUID, in context: ModelContext, from offset: Int, older: Bool, now: Date = .now
    ) throws -> Int? {
        if !older && offset == 0 { return nil }
        let window = weekWindow(offset: offset, now: now)
        var descriptor: FetchDescriptor<CountEntry>
        if older {
            let bound = window.start
            descriptor = FetchDescriptor<CountEntry>(
                predicate: #Predicate { $0.timestamp < bound },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
        } else {
            let bound = window.end
            descriptor = FetchDescriptor<CountEntry>(
                predicate: #Predicate { $0.timestamp >= bound },
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
        }
        // 他項目の記録が手前に並びうるので、この項目の1件目が出るまで読む。
        descriptor.fetchLimit = 200
        var scanned = 0
        while true {
            let page = try context.fetch(descriptor)
            if let hit = page.first(where: { $0.counter?.id == counterID }) {
                return weekOffset(containing: hit.timestamp, now: now)
            }
            if page.count < descriptor.fetchLimit! { return nil }
            scanned += page.count
            descriptor.fetchOffset = scanned
        }
    }

    /// 今日の記録のうち、その項目の最も新しい1件。無ければ nil。
    /// 誤タップの取り消しに使う。当日分しか見ないのは、直したいのは「今押したもの」だけで、
    /// 昨日以前の記録を巻き戻す口をここに作ると誤操作の方が怖いため。
    static func latestEntryToday(
        counterID: UUID, in context: ModelContext, now: Date = .now
    ) throws -> CountEntry? {
        let start = startOfDay(now)
        let end = nextMidnight(after: now)
        var descriptor = FetchDescriptor<CountEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        // 当日分は多くても数十件なので、全部読んでから項目で選り分ける。
        descriptor.fetchLimit = 200
        return try context.fetch(descriptor).first { $0.counter?.id == counterID }
    }

    /// 今日の直前の記録を1件取り消す。取り消した量を返す（何も無ければ nil）。
    @discardableResult
    static func undoLatestToday(
        counterID: UUID, in context: ModelContext, now: Date = .now
    ) throws -> Int? {
        guard let entry = try latestEntryToday(counterID: counterID, in: context, now: now) else { return nil }
        let amount = entry.amount
        context.delete(entry)
        try context.save()
        return amount
    }

    /// 1タップ分を記録する。ウィジェットの AppIntent からも呼ぶ。
    @discardableResult
    static func increment(counterID: UUID, in context: ModelContext, now: Date = .now) throws -> Int {
        let descriptor = FetchDescriptor<CounterItem>(predicate: #Predicate { $0.id == counterID })
        guard let counter = try context.fetch(descriptor).first else { return 0 }
        context.insert(CountEntry(timestamp: now, amount: counter.step, counter: counter))
        try context.save()
        return counter.step
    }
}

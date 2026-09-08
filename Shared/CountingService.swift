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

    /// 直近7日分の日別合計を古い順に返す（末尾が今日）。
    static func lastWeekTotals(for counter: CounterItem, now: Date = .now) -> [(date: Date, total: Int)] {
        let today = startOfDay(now)
        let calendar = Calendar.current
        let days: [Date] = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        let entries = counter.entries ?? []
        return days.map { day in
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let total = entries.filter { $0.timestamp >= day && $0.timestamp < next }.reduce(0) { $0 + $1.amount }
            return (day, total)
        }
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

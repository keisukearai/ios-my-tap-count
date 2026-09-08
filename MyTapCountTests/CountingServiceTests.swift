import Foundation
import SwiftData
import Testing
@testable import MyTapCount

@Suite("日付の境界")
struct DayBoundaryTests {
    @Test("当日の 0 時を返す")
    func startOfDay() {
        let noon = TestSupport.date(2026, 9, 8, 12, 34)
        #expect(CountingService.startOfDay(noon) == TestSupport.date(2026, 9, 8))
    }

    @Test("0 時ちょうどはその日の始まりのまま")
    func startOfDayAtMidnight() {
        let midnight = TestSupport.date(2026, 9, 8)
        #expect(CountingService.startOfDay(midnight) == midnight)
    }

    @Test("次に日付が変わる瞬間を返す")
    func nextMidnight() {
        #expect(CountingService.nextMidnight(after: TestSupport.date(2026, 9, 8, 23, 59)) == TestSupport.date(2026, 9, 9))
        #expect(CountingService.nextMidnight(after: TestSupport.date(2026, 9, 8)) == TestSupport.date(2026, 9, 9))
    }

    @Test("月をまたいでも次の日を返す")
    func nextMidnightAcrossMonth() {
        #expect(CountingService.nextMidnight(after: TestSupport.date(2026, 9, 30, 22, 0)) == TestSupport.date(2026, 10, 1))
    }
}

@Suite("カウンターの取得")
struct CounterFetchTests {
    private let store = TestStore()

    @Test("sortOrder の順に返す（自動並べ替えはしない）")
    func sortedBySortOrder() throws {
        let context = store.context
        TestSupport.makeCounter(in: context, name: "薬", sortOrder: 2)
        TestSupport.makeCounter(in: context, name: "水", sortOrder: 0)
        TestSupport.makeCounter(in: context, name: "腕立て", sortOrder: 1)

        #expect(try CountingService.counters(in: context).map(\.name) == ["水", "腕立て", "薬"])
    }

    @Test("sortOrder が同じなら作成順に返す")
    func tieBreakByCreatedAt() throws {
        let context = store.context
        let older = CounterItem(name: "先", sortOrder: 0, createdAt: TestSupport.date(2026, 9, 1))
        let newer = CounterItem(name: "後", sortOrder: 0, createdAt: TestSupport.date(2026, 9, 5))
        context.insert(newer)
        context.insert(older)

        #expect(try CountingService.counters(in: context).map(\.name) == ["先", "後"])
    }

    @Test("1件も無ければ空を返す")
    func empty() throws {
        let context = store.context
        #expect(try CountingService.counters(in: context).isEmpty)
    }
}

@Suite("今日のカウント")
struct TodayTotalsTests {
    private let store = TestStore()

    @Test("当日分だけを項目ごとに合計する")
    func sumsTodayOnly() throws {
        let context = store.context
        let now = TestSupport.date(2026, 9, 8, 15, 0)
        let water = TestSupport.makeCounter(in: context, name: "水")
        let pills = TestSupport.makeCounter(in: context, name: "薬", sortOrder: 1)

        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 8, 0), in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 12, 0), in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 7, 23, 59), in: context)
        TestSupport.addEntry(pills, at: TestSupport.date(2026, 9, 8, 9, 0), in: context)

        let totals = try CountingService.todayTotals(in: context, now: now)
        #expect(totals[water.id] == 2)
        #expect(totals[pills.id] == 1)
    }

    @Test("step が 1 より大きい記録は増分をそのまま足す")
    func sumsAmounts() throws {
        let context = store.context
        let now = TestSupport.date(2026, 9, 8, 20, 0)
        let pushups = TestSupport.makeCounter(in: context, name: "腕立て", step: 10)
        TestSupport.addEntry(pushups, at: TestSupport.date(2026, 9, 8, 7, 0), amount: 10, in: context)
        TestSupport.addEntry(pushups, at: TestSupport.date(2026, 9, 8, 19, 0), amount: 20, in: context)

        #expect(try CountingService.todayTotals(in: context, now: now)[pushups.id] == 30)
    }

    @Test("翌日の記録は当日に数えない")
    func excludesTomorrow() throws {
        let context = store.context
        let now = TestSupport.date(2026, 9, 8, 10, 0)
        let water = TestSupport.makeCounter(in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 9, 0, 1), in: context)

        #expect(try CountingService.todayTotals(in: context, now: now)[water.id] == nil)
    }

    @Test("日付が変われば当日カウントは 0 から始まる")
    func resetsAtMidnight() throws {
        let context = store.context
        let water = TestSupport.makeCounter(in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 22, 0), in: context)

        let beforeMidnight = try CountingService.todayTotals(in: context, now: TestSupport.date(2026, 9, 8, 23, 59))
        let afterMidnight = try CountingService.todayTotals(in: context, now: TestSupport.date(2026, 9, 9, 0, 1))
        #expect(beforeMidnight[water.id] == 1)
        #expect(afterMidnight[water.id] == nil)
    }

    @Test("記録が無い項目は辞書に現れない")
    func missingCounterIsAbsent() throws {
        let context = store.context
        let water = TestSupport.makeCounter(in: context)
        #expect(try CountingService.todayTotals(in: context, now: .now)[water.id] == nil)
    }
}

@Suite("記録の追加")
struct IncrementTests {
    private let store = TestStore()

    @Test("その項目の step の分だけ記録を1件足す")
    func addsOneEntryWithStep() throws {
        let context = store.context
        let now = TestSupport.date(2026, 9, 8, 10, 0)
        let pushups = TestSupport.makeCounter(in: context, name: "腕立て", step: 10)

        let added = try CountingService.increment(counterID: pushups.id, in: context, now: now)

        #expect(added == 10)
        #expect(pushups.entries?.count == 1)
        #expect(pushups.entries?.first?.amount == 10)
        #expect(pushups.entries?.first?.timestamp == now)
        #expect(try CountingService.todayTotals(in: context, now: now)[pushups.id] == 10)
    }

    @Test("知らない ID なら何も足さない")
    func unknownIDDoesNothing() throws {
        let context = store.context
        TestSupport.makeCounter(in: context)

        #expect(try CountingService.increment(counterID: UUID(), in: context) == 0)
        #expect(try context.fetch(FetchDescriptor<CountEntry>()).isEmpty)
    }

    @Test("押した回数だけ記録が増える")
    func repeatedTaps() throws {
        let context = store.context
        let now = TestSupport.date(2026, 9, 8, 10, 0)
        let water = TestSupport.makeCounter(in: context)

        for _ in 0..<3 { try CountingService.increment(counterID: water.id, in: context, now: now) }

        #expect(try CountingService.todayTotals(in: context, now: now)[water.id] == 3)
    }
}

@Suite("週単位の履歴")
struct WeekHistoryTests {
    private let store = TestStore()

    private let now = TestSupport.date(2026, 9, 8, 12, 0)

    // MARK: 週の範囲

    @Test("offset 0 は今日を含む直近7日")
    func currentWeekWindow() {
        let window = CountingService.weekWindow(offset: 0, now: now)
        #expect(window.start == TestSupport.date(2026, 9, 2))
        #expect(window.end == TestSupport.date(2026, 9, 9))
    }

    @Test("offset 1 は7日ぶん古い")
    func previousWeekWindow() {
        let window = CountingService.weekWindow(offset: 1, now: now)
        #expect(window.start == TestSupport.date(2026, 8, 26))
        #expect(window.end == TestSupport.date(2026, 9, 2))
    }

    @Test("その日がどの週に入るか")
    func offsetContainingDate() {
        #expect(CountingService.weekOffset(containing: TestSupport.date(2026, 9, 8), now: now) == 0)
        #expect(CountingService.weekOffset(containing: TestSupport.date(2026, 9, 2), now: now) == 0)
        #expect(CountingService.weekOffset(containing: TestSupport.date(2026, 9, 1), now: now) == 1)
        #expect(CountingService.weekOffset(containing: TestSupport.date(2026, 8, 26), now: now) == 1)
        #expect(CountingService.weekOffset(containing: TestSupport.date(2026, 8, 25), now: now) == 2)
    }

    @Test("未来の日付は今週に丸める")
    func futureDateClampsToCurrentWeek() {
        #expect(CountingService.weekOffset(containing: TestSupport.date(2026, 9, 20), now: now) == 0)
    }

    // MARK: 期間を絞った取得

    @Test("期間の外の記録は取らない")
    func entriesStayInsideWindow() throws {
        let context = store.context
        let water = TestSupport.makeCounter(in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 1, 23, 59), in: context)   // 範囲の直前
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 2, 0, 0), in: context)     // start は含む
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 23, 59), in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 9, 0, 0), in: context)     // end は含まない

        let window = CountingService.weekWindow(offset: 0, now: now)
        let entries = try CountingService.entries(
            counterID: water.id, in: context, from: window.start, to: window.end
        )
        #expect(entries.count == 2)
        #expect(entries.map(\.timestamp).sorted() == [
            TestSupport.date(2026, 9, 2, 0, 0),
            TestSupport.date(2026, 9, 8, 23, 59),
        ])
    }

    @Test("他の項目の記録は混ざらない")
    func entriesFilterByCounter() throws {
        let context = store.context
        let water = TestSupport.makeCounter(in: context, name: "水")
        let pills = TestSupport.makeCounter(in: context, name: "薬", sortOrder: 1)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 5, 9, 0), in: context)
        TestSupport.addEntry(pills, at: TestSupport.date(2026, 9, 5, 10, 0), in: context)

        let window = CountingService.weekWindow(offset: 0, now: now)
        let entries = try CountingService.entries(
            counterID: water.id, in: context, from: window.start, to: window.end
        )
        #expect(entries.count == 1)
        #expect(entries.first?.counter?.id == water.id)
    }

    // MARK: 日別合計

    @Test("古い順に7日分を返し、末尾が今日になる")
    func sevenDaysOldestFirst() {
        let window = CountingService.weekWindow(offset: 0, now: now)
        let totals = CountingService.dayTotals([], window: window)
        #expect(totals.count == 7)
        #expect(totals.first?.date == TestSupport.date(2026, 9, 2))
        #expect(totals.last?.date == TestSupport.date(2026, 9, 8))
    }

    @Test("日ごとに合計する")
    func totalsPerDay() throws {
        let context = store.context
        let water = TestSupport.makeCounter(in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 6, 8, 0), in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 6, 20, 0), in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 9, 0), in: context)

        let window = CountingService.weekWindow(offset: 0, now: now)
        let entries = try CountingService.entries(
            counterID: water.id, in: context, from: window.start, to: window.end
        )
        #expect(CountingService.dayTotals(entries, window: window).map(\.total) == [0, 0, 0, 0, 2, 0, 1])
    }

    @Test("増分は記録時の amount で足す")
    func totalsUseRecordedAmount() throws {
        let context = store.context
        let pushups = TestSupport.makeCounter(in: context, name: "腕立て", step: 10)
        TestSupport.addEntry(pushups, at: TestSupport.date(2026, 9, 7, 8, 0), amount: 10, in: context)
        TestSupport.addEntry(pushups, at: TestSupport.date(2026, 9, 7, 9, 0), amount: 20, in: context)

        let window = CountingService.weekWindow(offset: 0, now: now)
        let entries = try CountingService.entries(
            counterID: pushups.id, in: context, from: window.start, to: window.end
        )
        #expect(CountingService.dayTotals(entries, window: window).map(\.total) == [0, 0, 0, 0, 0, 30, 0])
    }

    @Test("8日前の記録は今週に含めない")
    func excludesOlderThanSevenDays() throws {
        let context = store.context
        let water = TestSupport.makeCounter(in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 1, 12, 0), in: context)

        let window = CountingService.weekWindow(offset: 0, now: now)
        let entries = try CountingService.entries(
            counterID: water.id, in: context, from: window.start, to: window.end
        )
        #expect(CountingService.dayTotals(entries, window: window).allSatisfy { $0.total == 0 })
    }

    // MARK: 週送り

    @Test("記録の無い週は飛ばして古い方へ進む")
    func skipsEmptyWeeksGoingOlder() throws {
        let context = store.context
        let water = TestSupport.makeCounter(in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 9, 0), in: context)   // offset 0
        TestSupport.addEntry(water, at: TestSupport.date(2026, 8, 10, 9, 0), in: context)  // offset 4

        let older = try CountingService.adjacentWeekOffset(
            counterID: water.id, in: context, from: 0, older: true, now: now
        )
        #expect(older == 4)
    }

    @Test("それ以上古い記録が無ければ nil")
    func noOlderWeekReturnsNil() throws {
        let context = store.context
        let water = TestSupport.makeCounter(in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 9, 0), in: context)

        #expect(try CountingService.adjacentWeekOffset(
            counterID: water.id, in: context, from: 0, older: true, now: now
        ) == nil)
    }

    @Test("古い週から新しい方へ戻れる")
    func stepsBackToNewerWeek() throws {
        let context = store.context
        let water = TestSupport.makeCounter(in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 9, 0), in: context)   // offset 0
        TestSupport.addEntry(water, at: TestSupport.date(2026, 8, 10, 9, 0), in: context)  // offset 4

        let newer = try CountingService.adjacentWeekOffset(
            counterID: water.id, in: context, from: 4, older: false, now: now
        )
        #expect(newer == 0)
    }

    @Test("今週では新しい方へは進めない")
    func noNewerWeekFromCurrent() throws {
        let context = store.context
        let water = TestSupport.makeCounter(in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 9, 0), in: context)

        #expect(try CountingService.adjacentWeekOffset(
            counterID: water.id, in: context, from: 0, older: false, now: now
        ) == nil)
    }

    @Test("他の項目の記録では週を送らない")
    func neighborsIgnoreOtherCounters() throws {
        let context = store.context
        let water = TestSupport.makeCounter(in: context, name: "水")
        let pills = TestSupport.makeCounter(in: context, name: "薬", sortOrder: 1)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 9, 0), in: context)
        TestSupport.addEntry(pills, at: TestSupport.date(2026, 8, 10, 9, 0), in: context)

        #expect(try CountingService.adjacentWeekOffset(
            counterID: water.id, in: context, from: 0, older: true, now: now
        ) == nil)
    }

    @Test("同じ週に複数の記録があっても週は1つ")
    func multipleEntriesInSameWeekGiveOneOffset() throws {
        let context = store.context
        let water = TestSupport.makeCounter(in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 9, 0), in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 8, 30, 9, 0), in: context)  // offset 1
        TestSupport.addEntry(water, at: TestSupport.date(2026, 8, 27, 9, 0), in: context)  // offset 1

        #expect(try CountingService.adjacentWeekOffset(
            counterID: water.id, in: context, from: 0, older: true, now: now
        ) == 1)
    }
}

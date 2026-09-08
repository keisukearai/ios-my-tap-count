import Foundation
import SwiftData
import Testing
@testable import MyTapCount

@Suite("カウンター項目")
struct CounterItemTests {
    @Test("既定値は step 1・目標なし")
    func defaults() {
        let counter = CounterItem(name: "水")
        #expect(counter.step == 1)
        #expect(counter.target == nil)
        #expect(counter.sortOrder == 0)
        #expect(counter.symbol == CounterSymbol.fallback)
        #expect(counter.colorKey == CounterColor.green.rawValue)
    }

    @Test("colorKey から色を引く")
    func resolvesColor() {
        #expect(CounterItem(name: "水", colorKey: CounterColor.blue.rawValue).color == .blue)
    }

    @Test("知らない colorKey は green に落とす")
    func unknownColorFallsBack() {
        #expect(CounterItem(name: "水", colorKey: "no-such-color").color == .green)
    }
}

@Suite("記録の削除")
struct DeletionTests {
    private let store = TestStore()

    @Test("カウンターを消すと紐づく記録も消える")
    func cascadeDelete() throws {
        let context = store.context
        let water = TestSupport.makeCounter(in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 8, 0), in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 9, 0), in: context)
        try context.save()

        context.delete(water)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<CounterItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CountEntry>()).isEmpty)
    }

    @Test("記録を1件消しても他の項目は残る")
    func deleteSingleEntry() throws {
        let context = store.context
        let now = TestSupport.date(2026, 9, 8, 12, 0)
        let water = TestSupport.makeCounter(in: context)
        let mistake = TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 8, 0), in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 9, 0), in: context)
        try context.save()

        context.delete(mistake)
        try context.save()

        #expect(try CountingService.todayTotals(in: context, now: now)[water.id] == 1)
    }
}

@Suite("記録時の増分の保存")
struct AmountSnapshotTests {
    private let store = TestStore()

    @Test("あとから step を変えても過去の記録は変わらない")
    func keepsAmountWhenStepChanges() throws {
        let context = store.context
        let now = TestSupport.date(2026, 9, 8, 10, 0)
        let pushups = TestSupport.makeCounter(in: context, name: "腕立て", step: 10)
        try CountingService.increment(counterID: pushups.id, in: context, now: now)

        pushups.step = 5
        try CountingService.increment(counterID: pushups.id, in: context, now: now)

        #expect(pushups.entries?.map(\.amount).sorted() == [5, 10])
        #expect(try CountingService.todayTotals(in: context, now: now)[pushups.id] == 15)
    }
}

@Suite("目標に対する進捗")
struct ProgressRatioTests {
    @Test("達成率を 0〜1 で返す")
    func ratio() {
        #expect(progressRatio(today: 3, target: 8) == 0.375)
        #expect(progressRatio(today: 0, target: 8) == 0)
    }

    @Test("目標を超えても 1 で止める")
    func caps() {
        #expect(progressRatio(today: 20, target: 8) == 1)
    }

    @Test("目標が無い・0 なら進捗を出さない")
    func noTarget() {
        #expect(progressRatio(today: 3, target: nil) == nil)
        #expect(progressRatio(today: 3, target: 0) == nil)
    }
}

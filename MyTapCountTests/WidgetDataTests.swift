import Foundation
import SwiftData
import Testing
@testable import MyTapCount

@Suite("ウィジェットに渡すデータ")
struct WidgetDataTests {
    private let store = TestStore()

    @Test("一覧と同じ順（sortOrder 順）で返す")
    func keepsUserOrder() throws {
        let context = store.context
        TestSupport.makeCounter(in: context, name: "薬", sortOrder: 2)
        TestSupport.makeCounter(in: context, name: "水", sortOrder: 0)
        TestSupport.makeCounter(in: context, name: "腕立て", sortOrder: 1)

        #expect(WidgetData.snapshots(in: context).map(\.name) == ["水", "腕立て", "薬"])
    }

    @Test("当日のカウントと目標を持たせる")
    func carriesTodayAndTarget() throws {
        let context = store.context
        let now = TestSupport.date(2026, 9, 8, 15, 0)
        let water = TestSupport.makeCounter(in: context, name: "水", target: 8)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 8, 0), in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 8, 10, 0), in: context)
        TestSupport.addEntry(water, at: TestSupport.date(2026, 9, 7, 10, 0), in: context)

        let snapshot = try #require(WidgetData.snapshots(in: context, now: now).first)
        #expect(snapshot.today == 2)
        #expect(snapshot.target == 8)
        #expect(snapshot.id == water.id)
    }

    @Test("目標なしの項目は target が nil")
    func targetlessCounter() throws {
        let context = store.context
        TestSupport.makeCounter(in: context, name: "腕立て", step: 10)
        #expect(WidgetData.snapshots(in: context).first?.target == nil)
    }

    @Test("アイコンと色をそのまま渡す")
    func carriesAppearance() throws {
        let context = store.context
        TestSupport.makeCounter(in: context, colorKey: CounterColor.purple.rawValue, symbol: "figure.walk")

        let snapshot = try #require(WidgetData.snapshots(in: context).first)
        #expect(snapshot.symbol == "figure.walk")
        #expect(snapshot.colorHex == CounterColor.purple.hex)
    }

    @Test("記録が無ければ 0 になる")
    func zeroWhenNoEntries() throws {
        let context = store.context
        TestSupport.makeCounter(in: context)
        #expect(WidgetData.snapshots(in: context).first?.today == 0)
    }

    @Test("カウンターが無ければ空を返す")
    func emptyStore() throws {
        let context = store.context
        #expect(WidgetData.snapshots(in: context).isEmpty)
    }

    @Test("ギャラリー用のプレースホルダは medium の行数ぶん用意する")
    func placeholders() {
        #expect(WidgetData.placeholders.count == 4)
        #expect(WidgetData.placeholders.allSatisfy { !$0.name.isEmpty })
    }
}

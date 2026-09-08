import Foundation
import SwiftData
import Testing
@testable import MyTapCount

/// テスト用のメモリ上ストア。
///
/// **`ModelContext` は `ModelContainer` を保持しない。** `container.mainContext` だけを
/// 受け取ってコンテナを手放すと、コンテナが解放された時点で以降の SwiftData 操作が
/// EXC_BREAKPOINT で落ちる（解放のタイミング次第なので、テストが1本のときは通ってしまう）。
/// スイートのプロパティとして持たせ、テストが終わるまでコンテナを生かしておく。
final class TestStore {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() {
        do {
            container = try ModelContainer(
                for: CounterItem.self, CountEntry.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("テスト用の ModelContainer を作れませんでした: \(error)")
        }
    }
}

enum TestSupport {
    /// 端末の言語設定や保存済みの選択に左右されない Localizer。
    static func localizer(_ language: AppLanguage) -> Localizer {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let localizer = Localizer(defaults: defaults)
        localizer.selection = language
        return localizer
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    @discardableResult
    static func makeCounter(
        in context: ModelContext,
        name: String = "水",
        step: Int = 1,
        target: Int? = nil,
        sortOrder: Int = 0,
        colorKey: String = CounterColor.blue.rawValue,
        symbol: String = "drop.fill"
    ) -> CounterItem {
        let counter = CounterItem(
            name: name, symbol: symbol, colorKey: colorKey,
            step: step, target: target, sortOrder: sortOrder
        )
        context.insert(counter)
        return counter
    }

    @discardableResult
    static func addEntry(_ counter: CounterItem, at date: Date, amount: Int = 1, in context: ModelContext) -> CountEntry {
        let entry = CountEntry(timestamp: date, amount: amount, counter: counter)
        context.insert(entry)
        return entry
    }
}

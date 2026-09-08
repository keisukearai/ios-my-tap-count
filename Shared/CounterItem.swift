import Foundation
import SwiftData

/// カウンター項目。ウィジェット設定からは `id` で参照する。
@Model
final class CounterItem {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    /// SF Symbols 名。`CounterSymbol.presets` から選ぶ。
    var symbol: String = CounterSymbol.fallback
    /// `CounterColor` の rawValue。
    var colorKey: String = CounterColor.green.rawValue
    /// 1タップで増える数。
    var step: Int = 1
    /// 1日の目標回数。nil なら進捗表示なし。
    var target: Int?
    /// 並び順。ユーザーが決めた順を保持し、自動並べ替えはしない
    /// （ウィジェットの表示順とずれると「どれを押したか」が分からなくなるため）。
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \CountEntry.counter)
    var entries: [CountEntry]? = []

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String = CounterSymbol.fallback,
        colorKey: String = CounterColor.green.rawValue,
        step: Int = 1,
        target: Int? = nil,
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.colorKey = colorKey
        self.step = step
        self.target = target
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    var color: CounterColor { CounterColor(rawValue: colorKey) ?? .green }
}

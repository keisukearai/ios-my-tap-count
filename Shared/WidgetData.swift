import Foundation
import SwiftData

/// ウィジェットに描くために切り出したカウンター1件分。
///
/// SwiftData のオブジェクトをそのまま Timeline に載せず、値型に写してから渡す。
/// エントリは日付が変わったあとにも描画されるので、そのときに生きたモデルを
/// 触らないようにするため。
struct CounterSnapshot: Identifiable, Hashable {
    let id: UUID
    let name: String
    let symbol: String
    let colorHex: UInt32
    let today: Int
    let target: Int?
}

enum WidgetData {
    /// 共有ストアから読む。ウィジェット拡張から呼ぶ入口。
    static func snapshots(now: Date = .now) -> [CounterSnapshot] {
        snapshots(in: ModelContext(SharedModelContainer.shared), now: now)
    }

    /// 拡張はメモリ制限が厳しいので、当日分の記録しか読まない。
    static func snapshots(in context: ModelContext, now: Date = .now) -> [CounterSnapshot] {
        guard let counters = try? CountingService.counters(in: context) else { return [] }
        let totals = (try? CountingService.todayTotals(in: context, now: now)) ?? [:]
        return counters.map { counter in
            CounterSnapshot(
                id: counter.id,
                name: counter.name,
                symbol: counter.symbol,
                colorHex: counter.color.hex,
                today: totals[counter.id] ?? 0,
                target: counter.target
            )
        }
    }

    /// プレビュー・プレースホルダ用。実データが無いギャラリー表示でも形が分かるようにする。
    static let placeholders: [CounterSnapshot] = [
        CounterSnapshot(id: UUID(), name: "水", symbol: "drop.fill", colorHex: CounterColor.blue.hex, today: 3, target: 8),
        CounterSnapshot(id: UUID(), name: "腕立て", symbol: "dumbbell.fill", colorHex: CounterColor.orange.hex, today: 20, target: nil),
        CounterSnapshot(id: UUID(), name: "薬", symbol: "pills.fill", colorHex: CounterColor.green.hex, today: 1, target: 2),
        CounterSnapshot(id: UUID(), name: "ストレッチ", symbol: "figure.walk", colorHex: CounterColor.purple.hex, today: 1, target: 1),
    ]
}

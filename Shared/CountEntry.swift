import Foundation
import SwiftData

/// 記録1件。「今日のカウント」は保持せず、当日分の `amount` を合計して求める。
/// 保存しておくと日付が変わるタイミングでのリセット処理が必要になり、
/// アプリもウィジェットも動いていない深夜帯の扱いが破綻するため。
@Model
final class CountEntry {
    var timestamp: Date = Date()
    /// 増えた数。あとから step を変えても過去の記録が変わらないよう、記録時の値を持つ。
    var amount: Int = 1
    var counter: CounterItem?

    init(timestamp: Date = .now, amount: Int = 1, counter: CounterItem? = nil) {
        self.timestamp = timestamp
        self.amount = amount
        self.counter = counter
    }
}

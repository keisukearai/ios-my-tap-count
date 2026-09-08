#if DEBUG
import Foundation
import SwiftData

/// 動作確認・スクリーンショット用のサンプルデータ。
/// `xcrun simctl launch booted com.keisukearai.MyTapCount -seedSampleData` で投入する。
/// MyNfcTapLog と同じ運用（DEBUG のみ、起動引数で切り替え）。
enum SampleData {
    static var isRequested: Bool {
        CommandLine.arguments.contains("-seedSampleData")
    }

    static func seed(into context: ModelContext) {
        // 何度起動しても同じ状態になるよう、既存を消してから入れ直す
        try? context.delete(model: CountEntry.self)
        try? context.delete(model: CounterItem.self)

        let specs: [(String, String, CounterColor, Int, Int?, [Int])] = [
            ("水", "drop.fill", .blue, 1, 8, [7, 6, 8, 5, 8, 7, 3]),
            ("腕立て", "dumbbell.fill", .orange, 10, nil, [20, 0, 30, 20, 0, 20, 20]),
            ("薬", "pills.fill", .green, 1, 2, [2, 1, 2, 2, 0, 2, 1]),
            ("ストレッチ", "figure.walk", .purple, 1, 1, [1, 1, 0, 1, 1, 0, 0]),
        ]
        let today = CountingService.startOfDay()

        for (index, spec) in specs.enumerated() {
            let (name, symbol, color, step, target, week) = spec
            let counter = CounterItem(
                name: name, symbol: symbol, colorKey: color.rawValue,
                step: step, target: target, sortOrder: index
            )
            context.insert(counter)
            for (dayOffset, total) in week.enumerated() {
                guard total > 0 else { continue }
                let day = Calendar.current.date(byAdding: .day, value: dayOffset - 6, to: today) ?? today
                for tap in 0..<max(1, total / step) {
                    let time = day.addingTimeInterval(TimeInterval((8 + tap * 2) * 3600))
                    context.insert(CountEntry(timestamp: time, amount: step, counter: counter))
                }
            }
        }
        try? context.save()
    }
}
#endif

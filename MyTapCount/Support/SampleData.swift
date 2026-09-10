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

        // 項目名は表示言語に合わせる。App Store のスクリーンショットを ja / en の
        // 両方で撮るため、英語表示のまま日本語の項目名が並ばないようにする。
        let names: [String] = switch Localizer().language {
        case .ja: ["水", "腕立て", "薬", "ストレッチ"]
        case .en: ["Water", "Push-ups", "Medication", "Stretching"]
        }

        let specs: [(String, CounterColor, Int, Int?, [Int])] = [
            ("drop.fill", .blue, 1, 8, [7, 6, 8, 5, 8, 7, 3]),
            ("dumbbell.fill", .orange, 10, nil, [20, 0, 30, 20, 0, 20, 20]),
            ("pills.fill", .green, 1, 2, [2, 1, 2, 2, 0, 2, 1]),
            ("figure.walk", .purple, 1, 1, [1, 1, 0, 1, 1, 0, 0]),
        ]
        let today = CountingService.startOfDay()

        for (index, spec) in specs.enumerated() {
            let (symbol, color, step, target, week) = spec
            let counter = CounterItem(
                name: names[index], symbol: symbol, colorKey: color.rawValue,
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
        // 週送りを試せるよう、間を空けて古い週にも「水」の記録を置く。
        // 直近7日ぶんだけだと ◀ が常に無効で、空週スキップの確認ができない。
        let waterName = names[0]
        if let water = try? context.fetch(
            FetchDescriptor<CounterItem>(predicate: #Predicate { $0.name == waterName })
        ).first {
            for dayOffset in [-16, -17, -18, -30, -31] {
                let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: today) ?? today
                for tap in 0..<4 {
                    let time = day.addingTimeInterval(TimeInterval((9 + tap * 3) * 3600))
                    context.insert(CountEntry(timestamp: time, amount: 1, counter: water))
                }
            }
        }

        try? context.save()
    }
}
#endif

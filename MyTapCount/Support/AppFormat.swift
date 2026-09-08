import Foundation

/// 日付・時刻の表示。言語切り替えを即時に反映させるため、端末ロケールではなく
/// `Localizer` が持つロケールを明示的に渡す。
enum AppFormat {
    static func time(_ date: Date, _ localizer: Localizer) -> String {
        var formatter = Date.FormatStyle(date: .omitted, time: .shortened)
        formatter.locale = localizer.locale
        return date.formatted(formatter)
    }

    /// 履歴のセクション見出し。今日・昨日だけ言葉にする。
    static func daySection(_ day: Date, _ localizer: Localizer, now: Date = .now) -> String {
        let today = CountingService.startOfDay(now)
        if day >= today { return localizer.t("detail.today") }
        if day >= Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today {
            return localizer.t("detail.yesterday")
        }
        var formatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
        formatter.locale = localizer.locale
        return day.formatted(formatter)
    }

    /// 棒グラフの曜日ラベル。
    static func weekdayInitial(_ day: Date, _ localizer: Localizer) -> String {
        let formatter = DateFormatter()
        formatter.locale = localizer.locale
        let index = Calendar.current.component(.weekday, from: day) - 1
        let symbols = localizer.language == .ja ? formatter.veryShortStandaloneWeekdaySymbols : formatter.shortStandaloneWeekdaySymbols
        return symbols?[index] ?? ""
    }
}

import Foundation
import Testing
@testable import MyTapCount

@Suite("時刻の表示")
struct TimeFormatTests {
    @Test("日本語は24時間表記で出す")
    func japanese() {
        let time = AppFormat.time(TestSupport.date(2026, 9, 8, 20, 5), TestSupport.localizer(.ja))
        #expect(time.contains("20:05"))
    }

    @Test("英語は午前・午後つきで出す")
    func english() {
        let time = AppFormat.time(TestSupport.date(2026, 9, 8, 20, 5), TestSupport.localizer(.en))
        #expect(time.contains("8:05"))
        #expect(time.contains("PM"))
    }

    @Test("端末の 12/24 時間設定に引きずられない")
    func independentOfDeviceSetting() {
        let morning = TestSupport.date(2026, 9, 8, 8, 0)
        #expect(AppFormat.time(morning, TestSupport.localizer(.ja)).contains("8:00"))
        #expect(AppFormat.time(morning, TestSupport.localizer(.en)).contains("AM"))
    }
}

@Suite("履歴の日付見出し")
struct DaySectionTests {
    private let now = TestSupport.date(2026, 9, 8, 12, 0)

    @Test("今日は「今日」と出す")
    func today() {
        let localizer = TestSupport.localizer(.ja)
        #expect(AppFormat.daySection(TestSupport.date(2026, 9, 8), localizer, now: now) == "今日")
        #expect(AppFormat.daySection(TestSupport.date(2026, 9, 8), TestSupport.localizer(.en), now: now) == "Today")
    }

    @Test("昨日は「昨日」と出す")
    func yesterday() {
        #expect(AppFormat.daySection(TestSupport.date(2026, 9, 7), TestSupport.localizer(.ja), now: now) == "昨日")
        #expect(AppFormat.daySection(TestSupport.date(2026, 9, 7), TestSupport.localizer(.en), now: now) == "Yesterday")
    }

    @Test("それより前は日付で出す")
    func olderDays() {
        let text = AppFormat.daySection(TestSupport.date(2026, 9, 5), TestSupport.localizer(.ja), now: now)
        #expect(text != "今日")
        #expect(text != "昨日")
        #expect(!text.isEmpty)
    }
}

@Suite("棒グラフの曜日ラベル")
struct WeekdayLabelTests {
    @Test("日本語は1文字で出す")
    func japanese() {
        #expect(AppFormat.weekdayInitial(TestSupport.date(2026, 9, 8), TestSupport.localizer(.ja)) == "火")
        #expect(AppFormat.weekdayInitial(TestSupport.date(2026, 9, 6), TestSupport.localizer(.ja)) == "日")
    }

    @Test("英語は3文字で出す")
    func english() {
        #expect(AppFormat.weekdayInitial(TestSupport.date(2026, 9, 8), TestSupport.localizer(.en)) == "Tue")
        #expect(AppFormat.weekdayInitial(TestSupport.date(2026, 9, 6), TestSupport.localizer(.en)) == "Sun")
    }

    @Test("直近7日ぶんの曜日がすべて埋まる")
    func coversWholeWeek() {
        let localizer = TestSupport.localizer(.ja)
        let days = (0..<7).map { TestSupport.date(2026, 9, 2 + $0) }
        let labels = days.map { AppFormat.weekdayInitial($0, localizer) }
        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect(Set(labels).count == 7)
    }
}

@Suite("週の見出し")
struct WeekRangeTests {

    @Test("日本語は M/D – M/D")
    func japaneseRange() {
        let localizer = TestSupport.localizer(.ja)
        let window = CountingService.weekWindow(offset: 0, now: TestSupport.date(2026, 9, 8, 12, 0))
        #expect(AppFormat.weekRange(start: window.start, end: window.end, localizer) == "9/2 – 9/8")
    }

    @Test("月をまたいでも両端の月を出す")
    func acrossMonths() {
        let localizer = TestSupport.localizer(.ja)
        let window = CountingService.weekWindow(offset: 1, now: TestSupport.date(2026, 9, 8, 12, 0))
        #expect(AppFormat.weekRange(start: window.start, end: window.end, localizer) == "8/26 – 9/1")
    }

    @Test("英語は年を出さない")
    func englishOmitsYear() {
        let localizer = TestSupport.localizer(.en)
        let window = CountingService.weekWindow(offset: 0, now: TestSupport.date(2026, 9, 8, 12, 0))
        let text = AppFormat.weekRange(start: window.start, end: window.end, localizer)
        #expect(text.contains("–"))
        #expect(!text.contains("2026"))
    }

    @Test("終端は期間の最終日で、翌日にはならない")
    func endIsInclusiveDay() {
        let localizer = TestSupport.localizer(.ja)
        let window = CountingService.weekWindow(offset: 0, now: TestSupport.date(2026, 9, 8, 12, 0))
        #expect(window.end == TestSupport.date(2026, 9, 9))
        #expect(AppFormat.weekRange(start: window.start, end: window.end, localizer).hasSuffix("9/8"))
    }
}

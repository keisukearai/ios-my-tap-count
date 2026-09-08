import Foundation
import Testing
@testable import MyTapCount

@Suite("表示言語の保存")
struct LanguageSelectionTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    @Test("初期状態は端末の設定に追従する")
    func startsAsSystem() {
        #expect(Localizer(defaults: defaults()).selection == nil)
    }

    @Test("選んだ言語が次回に引き継がれる")
    func persistsSelection() {
        let store = defaults()
        Localizer(defaults: store).selection = .en
        #expect(Localizer(defaults: store).selection == .en)
    }

    @Test("端末に追従へ戻すと選択が消える")
    func persistsSystemChoice() {
        let store = defaults()
        let localizer = Localizer(defaults: store)
        localizer.selection = .ja
        localizer.selection = nil
        #expect(Localizer(defaults: store).selection == nil)
    }

    @Test("未選択でも必ずどちらかの言語で解決する")
    func alwaysResolvesLanguage() {
        #expect(AppLanguage.allCases.contains(Localizer(defaults: defaults()).language))
    }

    @Test("ロケールは言語ごとに固定する")
    func fixedLocales() {
        #expect(AppLanguage.ja.locale.identifier == "ja_JP")
        #expect(AppLanguage.en.locale.identifier == "en_US")
    }
}

@Suite("文言の解決")
struct LocalizedTextTests {
    @Test("同じキーが言語ごとに違う文言になる")
    func switchesLanguage() {
        #expect(TestSupport.localizer(.ja).t("home.todayHeader") == "今日")
        #expect(TestSupport.localizer(.en).t("home.todayHeader") == "TODAY")
    }

    @Test("引数つきの文言に数値を差し込む")
    func formatsArguments() {
        #expect(TestSupport.localizer(.ja).t("counter.target", 8) == "目標 8")
        #expect(TestSupport.localizer(.en).t("counter.target", 8) == "Target 8")
        #expect(TestSupport.localizer(.ja).t("count.times", 3) == "3 回")
        #expect(TestSupport.localizer(.en).t("count.times", 3) == "3")
    }

    @Test("知らないキーはキー名をそのまま返す")
    func unknownKey() {
        #expect(TestSupport.localizer(.ja).t("no.such.key") == "no.such.key")
    }

    @Test("画面で使う主要な文言が両言語そろっている")
    func hasTranslationsForBothLanguages() {
        let keys = [
            "app.name", "home.todayHeader", "home.foot", "home.guideCta", "home.guideCtaSub",
            "home.empty.title", "home.empty.body", "menu.editCounter",
            "counter.targetReached", "detail.last7", "detail.swipeHint", "detail.today", "detail.yesterday",
            "form.icon", "form.color", "form.rules", "form.step", "form.targetOn", "form.targetCount",
            "form.namePlaceholder", "form.defaultName", "form.deleteCounter", "form.deleteNote",
            "form.titleAdd", "form.titleEdit",
            "settings.title", "settings.language", "settings.language.system", "settings.widget",
            "guide.title", "guide.lead", "guide.done", "guide.navTitle",
            "guide.step1.title", "guide.step1.body", "guide.step2.title", "guide.step2.body",
            "guide.step3.title", "guide.step3.body", "guide.step4.title", "guide.step4.body",
            "common.save", "common.cancel", "common.delete", "common.edit",
        ]
        for language in AppLanguage.allCases {
            let localizer = TestSupport.localizer(language)
            for key in keys {
                #expect(localizer.t(key) != key, "\(language.rawValue) に \(key) の訳が無い")
            }
        }
    }
}

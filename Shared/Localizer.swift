import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case ja
    case en

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ja: "日本語"
        case .en: "English"
        }
    }

    /// 日付・時刻の書式に使うロケール。端末の 12/24 時間設定に引きずられないよう固定 ID を使う。
    var locale: Locale {
        switch self {
        case .ja: Locale(identifier: "ja_JP")
        case .en: Locale(identifier: "en_US")
        }
    }

    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return allCases.first { preferred.hasPrefix($0.rawValue) } ?? .en
    }
}

/// アプリ内で言語を切り替えるための文言解決。
///
/// SwiftUI の `Text(LocalizedStringKey)` は端末の言語設定を見るため、設定画面での切り替えを
/// 即座に反映させるには参照する Bundle を自分で差し替える必要がある。String Catalog
/// (`Localizable.xcstrings`) はビルド時に `ja.lproj` / `en.lproj` の .strings に展開されるので、
/// 該当 lproj の Bundle を直接引くことで実現している。
/// 言語を増やすときは `AppLanguage` に case を足し、xcstrings に訳を足したうえで、
/// pbxproj の `knownRegions` にも言語コードを足す（無いと .lproj がビルドされない）。
///
/// 保存先は App Group の UserDefaults。ウィジェット拡張も同じ設定を読むため。
@Observable
final class Localizer {
    private static let storageKey = "appLanguage"
    /// 端末の言語設定に追従することを表す保存値。`AppLanguage.rawValue` のどれとも衝突しない。
    private static let systemValue = "system"

    @ObservationIgnored private let defaults: UserDefaults

    /// 設定画面で選んだ言語。nil は端末の言語設定に追従している状態。
    var selection: AppLanguage? {
        didSet { defaults.set(selection?.rawValue ?? Self.systemValue, forKey: Self.storageKey) }
    }

    var language: AppLanguage { selection ?? .systemDefault }
    var locale: Locale { language.locale }

    /// `defaults` を差し替えられるのはテストのため。
    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        selection = defaults.string(forKey: Self.storageKey).flatMap(AppLanguage.init(rawValue:))
    }

    private var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }

    /// 引数なしのときは String(format:) を通さない。文言に含まれる `%` を壊さないため。
    func t(_ key: String, _ args: CVarArg...) -> String {
        let raw = bundle.localizedString(forKey: key, value: key, table: nil)
        guard !args.isEmpty else { return raw }
        return String(format: raw, locale: language.locale, arguments: args)
    }
}

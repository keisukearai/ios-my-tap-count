import SwiftUI

/// 画面4: 設定。
struct SettingsView: View {
    @Environment(Localizer.self) private var localizer
    let onOpenGuide: () -> Void

    private var version: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "MyTapCount \(marketing) (\(build))"
    }

    var body: some View {
        @Bindable var localizer = localizer

        List {
            Section(localizer.t("settings.language")) {
                languageRow(title: localizer.t("settings.language.system"), selection: nil)
                ForEach(AppLanguage.allCases) { language in
                    languageRow(title: language.displayName, selection: language)
                }
            }

            Section(localizer.t("settings.widget")) {
                Button(action: onOpenGuide) {
                    HStack {
                        Text(localizer.t("home.guideCta"))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.faintInk.opacity(0.6))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Section {
                Text(version)
                    .font(Theme.mono(12, .medium))
                    .foregroundStyle(Theme.faintInk)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        .navigationTitle(localizer.t("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func languageRow(title: String, selection: AppLanguage?) -> some View {
        @Bindable var localizer = localizer
        return Button {
            localizer.selection = selection
        } label: {
            HStack {
                Text(title).foregroundStyle(Theme.ink)
                Spacer()
                if localizer.selection == selection {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

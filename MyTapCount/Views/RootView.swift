import SwiftUI
import SwiftData

enum Route: Hashable {
    case detail(UUID)
    case settings
    case guide
}

struct RootView: View {
    @Environment(Localizer.self) private var localizer
    @State private var path: [Route] = []
    @State private var editing: CounterFormView.Subject?
    /// 初回だけ設置ガイドを出す。ウィジェットを置いて初めて価値が出るアプリなので、
    /// 一覧が空のまま放置されるのを防ぐ。
    @AppStorage("hasSeenWidgetGuide", store: AppGroup.defaults) private var hasSeenWidgetGuide = false

    private var isScreenshotRun: Bool {
        #if DEBUG
        ScreenshotMode.requestedScreen != nil
        #else
        false
        #endif
    }

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                onOpenDetail: { path.append(.detail($0)) },
                onAdd: { editing = .new },
                onEdit: { editing = .existing($0) },
                onOpenGuide: { path.append(.guide) },
                onOpenSettings: { path.append(.settings) }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .detail(let id):
                    CounterDetailView(counterID: id, onEdit: { editing = .existing($0) })
                case .settings:
                    SettingsView(onOpenGuide: { path.append(.guide) })
                case .guide:
                    WidgetGuideView(onDone: { path.removeAll() })
                }
            }
            #if DEBUG
            .task { openRequestedScreen() }
            #endif
        }
        .tint(Theme.accent)
        .sheet(item: $editing) { subject in
            CounterFormView(subject: subject)
                .environment(localizer)
                .environment(\.locale, localizer.locale)
        }
        .sheet(isPresented: .constant(!hasSeenWidgetGuide && !isScreenshotRun)) {
            NavigationStack {
                WidgetGuideView(onDone: { hasSeenWidgetGuide = true })
            }
            .environment(localizer)
            .environment(\.locale, localizer.locale)
            .tint(Theme.accent)
            .interactiveDismissDisabled()
        }
    }

    #if DEBUG
    /// 起動引数で指定された画面まで push する。一覧の先頭を対象にする。
    private func openRequestedScreen() {
        guard let screen = ScreenshotMode.requestedScreen else { return }
        let context = SharedModelContainer.shared.mainContext
        switch screen {
        case "detail":
            if let first = try? CountingService.counters(in: context).first {
                path = [.detail(first.id)]
            }
        case "add": editing = .new
        case "settings": path = [.settings]
        case "guide": path = [.guide]
        default: break
        }
    }
    #endif
}

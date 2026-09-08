import SwiftUI
import SwiftData

@main
struct MyTapCountApp: App {
    @State private var localizer = Localizer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(localizer)
                .environment(\.locale, localizer.locale)
                .task {
                    #if DEBUG
                    if SampleData.isRequested {
                        SampleData.seed(into: SharedModelContainer.shared.mainContext)
                        AppGroup.defaults.set(true, forKey: "hasSeenWidgetGuide")
                    }
                    #endif
                }
        }
        .modelContainer(SharedModelContainer.shared)
    }
}

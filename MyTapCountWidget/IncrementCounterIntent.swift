import AppIntents
import SwiftData
import WidgetKit

/// ウィジェットの ＋ が押されたときに走る。iOS 17 以降はアプリを起動せず
/// 拡張のプロセス内で処理されるので、ここでストアに書いて表示を更新する。
struct IncrementCounterIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.increment.title"
    /// ショートカット App には出さない。ウィジェットのボタン専用。
    static var isDiscoverable: Bool { false }

    @Parameter(title: "widget.increment.counterID")
    var counterID: String

    init() {}

    init(counterID: UUID) {
        self.counterID = counterID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: counterID) else { return .result() }
        let context = ModelContext(SharedModelContainer.shared)
        try CountingService.increment(counterID: id, in: context)
        // 反映は OS の裁量。呼んでも即時とは限らない。
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

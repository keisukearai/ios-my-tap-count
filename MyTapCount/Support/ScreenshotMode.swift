#if DEBUG
import Foundation

/// 起動時に特定の画面を開くための指定。動作確認とスクリーンショット撮影用。
/// `xcrun simctl launch booted com.keisukearai.MyTapCount -seedSampleData -screen detail`
enum ScreenshotMode {
    static var requestedScreen: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "-screen"),
              CommandLine.arguments.indices.contains(index + 1)
        else { return nil }
        return CommandLine.arguments[index + 1]
    }
}
#endif

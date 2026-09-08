import Foundation

/// 本体アプリとウィジェット拡張でデータを共有するための App Group。
///
/// 設定漏れは「ウィジェットに何も出ない」という形でしか現れず原因が追いにくいので、
/// コンテナが取れない場合はフォールバックせずその場で落とす。黙って別の場所に
/// ストアを作ると、本体だけ正しく動いて拡張が空という最悪の状態になるため。
enum AppGroup {
    static let identifier = "group.com.keisukearai.MyTapCount"

    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            fatalError("App Group \(identifier) が entitlements に設定されていません（本体・ウィジェット拡張の両方に必要）")
        }
        return url
    }

    /// SwiftData のストア。既定の場所（各ターゲットのサンドボックス）だと共有されないので明示する。
    static var storeURL: URL {
        containerURL.appending(path: "MyTapCount.store")
    }

    /// 表示言語など、本体と拡張の双方が読む設定の置き場。
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

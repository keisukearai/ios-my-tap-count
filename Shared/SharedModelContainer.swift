import Foundation
import SwiftData

/// 本体と拡張の双方が同じストアを開くための ModelContainer。
enum SharedModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([CounterItem.self, CountEntry.self])
        let configuration = ModelConfiguration(schema: schema, url: AppGroup.storeURL)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("ModelContainer を作れませんでした: \(error)")
        }
    }()
}

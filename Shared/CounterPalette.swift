import SwiftUI

/// 色プリセット。デザイン（1b の色選択）の7色をそのまま持つ。
enum CounterColor: String, CaseIterable, Identifiable {
    case blue, green, orange, purple, red, teal, slate

    var id: String { rawValue }

    var hex: UInt32 {
        switch self {
        case .blue:   0x2F6FD0
        case .green:  0x2F7D4F
        case .orange: 0xC4691F
        case .purple: 0x6B4FA8
        case .red:    0xB3364A
        case .teal:   0x1F7A7A
        case .slate:  0x4B5563
        }
    }

    var color: Color { Color(hex: hex) }
    /// 一覧の行に薄く敷く進捗バーの色。
    var tint: Color { Color(hex: hex, opacity: 0.10) }
    /// 棒グラフの当日以外の棒。
    var muted: Color { Color(hex: hex, opacity: 0.45) }
}

/// アイコンプリセット。デザインは 6 列グリッドなので 6 の倍数で並べる。
enum CounterSymbol {
    static let fallback = "checkmark.circle.fill"

    static let presets: [String] = [
        "drop.fill", "cup.and.saucer.fill", "pills.fill", "cross.case.fill", "fork.knife", "leaf.fill",
        "dumbbell.fill", "figure.walk", "figure.run", "figure.strengthtraining.traditional", "bicycle", "flame.fill",
        "book.fill", "pencil", "brain.head.profile", "music.note", "sun.max.fill", "moon.fill",
        "bed.double.fill", "clock.fill", "heart.fill", "star.fill", "checkmark.circle.fill", "hand.thumbsup.fill",
    ]
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

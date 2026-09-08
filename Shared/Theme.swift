import SwiftUI

/// デザイン（MyTapCount.dc.html）の値をそのまま置いたもの。
enum Theme {
    static let accent = Color(hex: 0x2F7D4F)
    static let accentDeep = Color(hex: 0x1D5E3B)
    static let accentWash = Color(hex: 0x2F7D4F, opacity: 0.09)
    static let destructive = Color(hex: 0xD93B45)

    static let canvas = Color(hex: 0xF2F4F7)
    static let card = Color.white
    static let ink = Color(hex: 0x16181C)
    static let subInk = Color(hex: 0x3C3C43, opacity: 0.60)
    static let faintInk = Color(hex: 0x3C3C43, opacity: 0.50)
    static let hairline = Color(hex: 0x3C3C43, opacity: 0.12)

    static let cardRadius: CGFloat = 20
    static let blockRadius: CGFloat = 16
    static let cardShadow = Color.black.opacity(0.05)

    /// 数字は等幅。カウントが増えても桁が揺れないようにするため。
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

extension View {
    /// デザインの白カード（角丸 + 薄い影）。
    func cardSurface(radius: CGFloat = Theme.blockRadius) -> some View {
        background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Theme.cardShadow, radius: 1, x: 0, y: 1)
    }
}

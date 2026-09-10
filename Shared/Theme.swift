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
    /// 一覧の行下端に敷く進捗バーの土台と、1回分の目盛り線。
    static let progressTrack = Color(hex: 0x3C3C43, opacity: 0.045)
    static let progressTick = Color(hex: 0x3C3C43, opacity: 0.13)
    /// 記録直後に下部へ出す取り消しバー。地の色に沈まないよう暗い面で置く。
    static let toast = Color(hex: 0x16181C, opacity: 0.95)
    static let onToast = Color.white
    static let onToastSub = Color.white.opacity(0.72)
    static let toastButton = Color.white.opacity(0.14)

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

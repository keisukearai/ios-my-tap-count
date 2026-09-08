import SwiftUI

/// 画面5: ウィジェット設置ガイド。初回起動時に1度だけ出す。
struct WidgetGuideView: View {
    @Environment(Localizer.self) private var localizer
    let onDone: () -> Void

    private struct Step: Identifiable {
        let id: Int
        let titleKey: String
        let bodyKey: String
    }

    private let steps = (1...4).map { Step(id: $0, titleKey: "guide.step\($0).title", bodyKey: "guide.step\($0).body") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(localizer.t("guide.title"))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 6)
                Text(localizer.t("guide.lead"))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.subInk)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)

                ForEach(steps) { step in
                    stepCard(step)
                }

                Button(action: onDone) {
                    Text(localizer.t("guide.done"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.blockRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(16)
        }
        .background(Theme.canvas)
        .navigationTitle(localizer.t("guide.navTitle"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepCard(_ step: Step) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(step.id)")
                .font(Theme.mono(13))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Theme.accent, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(localizer.t(step.titleKey))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(localizer.t(step.bodyKey))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.subInk)
                    .fixedSize(horizontal: false, vertical: true)
                figure(for: step.id)
                    .frame(maxWidth: .infinity)
                    .frame(height: 104)
                    .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(Theme.hairline.opacity(2))
                    }
                    .padding(.top, 9)
            }
        }
        .padding(16)
        .cardSurface(radius: 18)
    }

    /// 手順の図。実機のスクリーンショットは載せられないので、記号で形だけ示す。
    @ViewBuilder
    private func figure(for step: Int) -> some View {
        switch step {
        case 1:
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Theme.hairline.opacity(1.5))
                        .frame(width: 26, height: 26)
                        .rotationEffect(.degrees(-4))
                }
                Circle()
                    .stroke(Theme.faintInk.opacity(0.7), lineWidth: 2)
                    .frame(width: 38, height: 38)
                    .padding(.leading, 4)
            }
        case 2:
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 30, height: 30)
                    .overlay { Image(systemName: "plus").font(.system(size: 17, weight: .bold)).foregroundStyle(.white) }
                Image(systemName: "arrow.right")
                    .foregroundStyle(Theme.faintInk)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.hairline.opacity(1.5))
                    .frame(width: 64, height: 40)
            }
        case 3:
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent.opacity(0.85))
                    .frame(width: 44, height: 44)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent.opacity(0.35))
                    .frame(width: 96, height: 44)
            }
        default:
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent.opacity(0.85))
                    .frame(width: 44, height: 44)
                Image(systemName: "hand.tap")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.faintInk)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.hairline.opacity(1.5))
                    .frame(width: 78, height: 26)
            }
        }
    }
}

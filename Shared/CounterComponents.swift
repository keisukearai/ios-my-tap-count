import SwiftUI

/// 角丸の四角にアイコンを載せたバッジ。一覧・詳細・ウィジェットで大きさだけ変える。
struct CounterBadge: View {
    let symbol: String
    let color: Color
    var side: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
            .fill(color)
            .frame(width: side, height: side)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: side * 0.52, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

/// 記録用の ＋。ウィジェットに合わせて本体にも `−` は置かない
/// （誤タップの修正は履歴のスワイプ削除に一本化する）。
struct PlusButton: View {
    let color: Color
    var diameter: CGFloat = 34
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: diameter, height: diameter)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: diameter * 0.5, weight: .bold))
                        .foregroundStyle(.white)
                }
                // タップ領域を丸より広く取る（行が低いので押しにくくならないように）
                .padding(7)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 「3 / 8」または「3」。目標の有無で形を変える。
struct CountLabel: View {
    let today: Int
    let target: Int?
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: 3) {
            Text("\(today)")
                .font(Theme.mono(size))
            if let target {
                Text("/ \(target)")
                    .font(Theme.mono(size * 0.7, .medium))
                    .foregroundStyle(Theme.subInk)
            }
        }
        .foregroundStyle(Theme.ink)
    }
}

/// 目標に対する達成率。目標なしは nil。
func progressRatio(today: Int, target: Int?) -> Double? {
    guard let target, target > 0 else { return nil }
    return min(1, Double(today) / Double(target))
}

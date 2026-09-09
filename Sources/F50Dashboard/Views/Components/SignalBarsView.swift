import SwiftUI

/// 5 格信号强度条。
struct SignalBarsView: View {
    var bars: Int?
    var barCount = 5
    var height: CGFloat = 16

    private var filled: Int { min(max(bars ?? 0, 0), barCount) }

    private var tint: Color {
        switch filled {
        case 0: return .secondary
        case 1, 2: return .orange
        default: return .green
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                // 每格逐级增高，最矮的一格仍占 40% 高度以便看清轮廓。
                let scale = 0.4 + (0.6 * Double(index + 1) / Double(barCount))
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(index < filled ? tint : Color.secondary.opacity(0.25))
                    .frame(width: 3, height: height * scale)
            }
        }
        .accessibilityLabel("信号强度 \(filled) 格，共 \(barCount) 格")
    }
}

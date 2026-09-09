import SwiftUI

/// 仪表盘上的一块指标卡片。
struct StatCard<Content: View>: View {
    var title: String
    var systemImage: String
    var tint: Color = .accentColor
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
                .symbolRenderingMode(.hierarchical)
                .imageScale(.medium)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(tint.opacity(0.12), lineWidth: 1)
        )
    }
}

/// 卡片里成对出现的“标签 / 数值”行。
struct MetricRow: View {
    var label: String
    var value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(valueColor)
        }
    }
}

/// 自绘的进度条。
///
/// 不用系统的 ProgressView：它在 ImageRenderer 里渲染不出来（会变成一块占位图），
/// 而文档截图正是靠 ImageRenderer 生成的。
struct ProgressBar: View {
    var value: Double
    var tint: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
    }
}

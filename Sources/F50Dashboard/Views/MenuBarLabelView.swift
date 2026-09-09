import SwiftUI

/// 画在菜单栏上的那一小块内容，会被渲染成模板图像交给 NSStatusItem。
///
/// 菜单栏（尤其刘海屏）寸土必争，所以做成两行小字，宽度压到 40 点以内。
struct MenuBarLabelView: View {
    var snapshot: DeviceSnapshot
    var isReachable: Bool

    var body: some View {
        HStack(spacing: 3) {
            SignalBarsView(bars: isReachable ? snapshot.signalBars : 0, height: 11)

            if isReachable {
                VStack(alignment: .trailing, spacing: 0) {
                    rateText(prefix: "↓", value: snapshot.downloadRate)
                    rateText(prefix: "↑", value: snapshot.uploadRate)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func rateText(prefix: String, value: Double) -> some View {
        Text("\(prefix)\(Format.compactRate(value))")
            .font(.system(size: 8, weight: .medium).monospacedDigit())
            .foregroundStyle(.black)
    }
}

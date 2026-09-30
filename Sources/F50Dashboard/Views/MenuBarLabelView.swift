import SwiftUI

/// 画在菜单栏上的那一小块内容，会被渲染成模板图像交给 NSStatusItem。
///
/// 菜单栏（尤其刘海屏）寸土必争，所以做成两行小字，宽度压到 40 点以内。
struct MenuBarLabelView: View {
    var snapshot: DeviceSnapshot
    var isReachable: Bool
    var unreadCount: Int = 0
    var rateUnit: RateUnit = .bytes

    var body: some View {
        HStack(spacing: 3) {
            SignalBarsView(bars: isReachable ? snapshot.signalBars : 0, height: 11)

            if isReachable {
                VStack(alignment: .trailing, spacing: 0) {
                    rateText(prefix: "↓", value: snapshot.downloadRate)
                    rateText(prefix: "↑", value: snapshot.uploadRate)
                }
            }

            // 有未读短信时加一个信封，数量多了就只显示图标
            if unreadCount > 0 {
                HStack(spacing: 1) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 7))
                    if unreadCount < 10 {
                        Text("\(unreadCount)")
                            .font(.system(size: 8, weight: .bold).monospacedDigit())
                    }
                }
                .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 2)
    }

    private func rateText(prefix: String, value: Double) -> some View {
        Text("\(prefix)\(Format.compactRate(value, unit: rateUnit))")
            .font(.system(size: 8, weight: .medium).monospacedDigit())
            .foregroundStyle(.black)
    }
}

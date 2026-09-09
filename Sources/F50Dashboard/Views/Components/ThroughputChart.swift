import Charts
import SwiftUI

/// 上下行速率走势图。
struct ThroughputChart: View {
    var samples: [RateSample]
    var upperBound: Double
    var showsAxes = true

    var body: some View {
        Chart {
            ForEach(samples) { sample in
                AreaMark(
                    x: .value("时间", sample.timestamp),
                    y: .value("速率", sample.download),
                    series: .value("方向", "下行")
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.blue.opacity(0.35), .blue.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("时间", sample.timestamp),
                    y: .value("速率", sample.download),
                    series: .value("方向", "下行")
                )
                .foregroundStyle(.blue)
                .lineStyle(.init(lineWidth: 1.5))
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("时间", sample.timestamp),
                    y: .value("速率", sample.upload),
                    series: .value("方向", "上行")
                )
                .foregroundStyle(.orange)
                .lineStyle(.init(lineWidth: 1.5))
                .interpolationMethod(.monotone)
            }
        }
        .chartYScale(domain: 0...upperBound)
        .chartLegend(.hidden)
        .chartYAxis {
            if showsAxes {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                    AxisValueLabel {
                        if let rate = value.as(Double.self) {
                            Text(Format.rate(rate)).font(.caption2)
                        }
                    }
                }
            }
        }
        .chartXAxis {
            if showsAxes {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
        }
    }
}

/// 图例上的一个色块加文字。
struct ChartKey: View {
    var color: Color
    var label: String
    var value: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit().weight(.medium))
        }
    }
}

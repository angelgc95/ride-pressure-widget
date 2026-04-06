import SwiftUI

struct PressureChartCard: View {
    enum Kind {
        case daily
        case hourly
    }

    let title: String
    let subtitle: String
    let points: [ChartPoint]
    let kind: Kind

    private var hourlyPlotWidth: CGFloat {
        HourlyChartMetrics.plotWidth(for: points.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(RidePressurePalette.tertiaryText)

            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(RidePressurePalette.secondaryText)
                .lineLimit(2)

            chartBody
            .padding(14)
            .background(Color(hex: "10151D"))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
        }
        .padding(18)
        .background(RidePressurePalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 20, y: 24)
    }

    @ViewBuilder
    private var chartBody: some View {
        switch kind {
        case .daily:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    PressurePlot(points: points, kind: kind)
                        .frame(height: 142)

                    yAxis
                }

                HStack(alignment: .top, spacing: 10) {
                    axisLabels
                    Color.clear.frame(width: 32, height: 1)
                }
            }
        case .hourly:
            HStack(alignment: .top, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        PressurePlot(points: points, kind: kind)
                            .frame(width: hourlyPlotWidth, height: 136)

                        axisLabels
                            .frame(width: hourlyPlotWidth, height: 26, alignment: .leading)
                    }
                }
                .defaultScrollAnchor(.leading)

                yAxis
            }
        }
    }

    private var yAxis: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("100")
                .padding(.top, 2)
            Spacer()
            Text("avg")
            Spacer()
            Text("0")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color(hex: "7D8795"))
    }

    @ViewBuilder
    private var axisLabels: some View {
        switch kind {
        case .daily:
            HStack(alignment: .top, spacing: 14) {
                ForEach(points) { point in
                    Text(point.label.isEmpty ? " " : point.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "6D7786"))
                        .frame(maxWidth: .infinity)
                }
            }
        case .hourly:
            HourlyAxisLabels(points: points)
                .frame(height: 24)
        }
    }
}

private struct PressurePlot: View {
    let points: [ChartPoint]
    let kind: PressureChartCard.Kind

    private var average: Double {
        guard !points.isEmpty else { return 0 }
        return points.map(\.score).reduce(0, +) / Double(points.count)
    }

    var body: some View {
        GeometryReader { proxy in
            let plotHeight = proxy.size.height
            let spacing = kind == .daily ? 14.0 : HourlyChartMetrics.spacing
            let barWidth = kind == .daily ? nil : HourlyChartMetrics.barWidth
            let averageY = plotHeight - plotHeight * CGFloat(clamp(average, min: 0, max: 100) / 100)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    pressureBar(
                        for: point,
                        plotHeight: plotHeight,
                        emphasized: index == 0
                    )
                    .frame(width: barWidth)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .background {
                ChartGrid(averageY: averageY, toneCount: points.count)
            }
        }
    }

    private func pressureBar(for point: ChartPoint, plotHeight: CGFloat, emphasized: Bool) -> some View {
        let cornerRadius = kind == .daily ? 8.0 : 4.0
        let tint = point.tone.tint
        let fillHeight = max(0, plotHeight * CGFloat(point.score / 100))

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.11))

            RoundedRectangle(cornerRadius: max(2, cornerRadius - 2), style: .continuous)
                .fill(tint)
                .frame(height: fillHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            if emphasized {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.45), lineWidth: 1.2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

private struct ChartGrid: View {
    let averageY: CGFloat
    let toneCount: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { ratio in
                    Path { path in
                        let y = proxy.size.height * ratio
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(ratio == 0.5 ? 0.08 : 0.05), lineWidth: 1)
                }

                Path { path in
                    path.move(to: CGPoint(x: 0, y: averageY))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: averageY))
                }
                .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 7]))

                HStack(spacing: 0) {
                    ForEach(0..<max(toneCount, 1), id: \.self) { index in
                        Rectangle()
                            .fill(.clear)
                            .overlay(alignment: .trailing) {
                                if index < max(toneCount - 1, 0) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.04))
                                        .frame(width: 1)
                                        .padding(.vertical, 4)
                                }
                            }
                    }
                }
            }
        }
    }
}

private struct HourlyAxisLabels: View {
    let points: [ChartPoint]

    var body: some View {
        HStack(alignment: .top, spacing: HourlyChartMetrics.spacing) {
            ForEach(points) { point in
                Text(point.label)
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundStyle(Color(hex: "8691A1"))
                    .frame(width: HourlyChartMetrics.barWidth)
            }
        }
    }
}

private func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
    Swift.max(minValue, Swift.min(maxValue, value))
}

private enum HourlyChartMetrics {
    static let barWidth: CGFloat = 18
    static let spacing: CGFloat = 10

    static func plotWidth(for count: Int) -> CGFloat {
        guard count > 0 else { return barWidth }
        return CGFloat(count) * barWidth + CGFloat(max(count - 1, 0)) * spacing
    }
}

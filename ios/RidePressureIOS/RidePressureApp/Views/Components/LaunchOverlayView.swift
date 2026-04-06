import SwiftUI

struct LaunchOverlayView: View {
    @State private var animate = false

    private let barHeights: [CGFloat] = [18, 34, 26, 40, 22, 30, 16, 28, 38, 24, 20, 32]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "0B0F15"),
                    Color(hex: "111723"),
                    Color(hex: "090C12")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("RIDE PRESSURE")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RidePressurePalette.accent)

                    Text("Reading live city pressure")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Observed routes, weather load, and demand timing are being prepared for the dashboard.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "A1ACBA"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(barHeights.enumerated()), id: \.offset) { index, height in
                        Capsule()
                            .fill(barColor(for: index))
                            .frame(width: 14, height: animate ? height : max(10, height * 0.45))
                            .animation(
                                .easeInOut(duration: 0.72)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.04),
                                value: animate
                            )
                    }
                }
                .frame(height: 48, alignment: .bottomLeading)

                HStack(spacing: 10) {
                    splashPill("Observed only", fill: Color(hex: "141B25"), stroke: Color(hex: "64748B").opacity(0.45), text: Color(hex: "CBD5E1"))
                    splashPill("6h refresh", fill: Color(hex: "1D1820"), stroke: RidePressurePalette.normal.opacity(0.5), text: Color(hex: "FFBF66"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
            .background(Color(hex: "10151D").opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.3), radius: 24, y: 24)
            .padding(24)
        }
        .onAppear {
            animate = true
        }
    }

    private func barColor(for index: Int) -> Color {
        switch index % 3 {
        case 0:
            return RidePressurePalette.favorable.opacity(0.92)
        case 1:
            return RidePressurePalette.normal.opacity(0.92)
        default:
            return RidePressurePalette.unfavorable.opacity(0.92)
        }
    }

    private func splashPill(_ label: String, fill: Color, stroke: Color, text: Color) -> some View {
        Text(label.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(fill)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(stroke, lineWidth: 1)
            }
    }
}

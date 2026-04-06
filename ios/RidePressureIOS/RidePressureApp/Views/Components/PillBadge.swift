import SwiftUI

struct PillBadge: View {
    let label: String
    let fill: Color
    let stroke: Color
    let text: Color

    init(label: String, tone: PressureTone) {
        self.label = label
        self.fill = tone.softFill
        self.stroke = tone.softStroke
        self.text = tone.tint
    }

    init(label: String, fill: Color, stroke: Color, text: Color) {
        self.label = label
        self.fill = fill
        self.stroke = stroke
        self.text = text
    }

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(fill)
            .overlay {
                Capsule()
                    .stroke(stroke, lineWidth: 1)
            }
            .clipShape(Capsule())
    }
}

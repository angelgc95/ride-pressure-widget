import SwiftUI

extension Color {
    init(hex: String, opacity: Double = 1) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        let value = Int(cleaned, radix: 16) ?? 0
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self = Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

enum RidePressurePalette {
    static let screenBackground = Color(hex: "090C12")
    static let panel = Color(hex: "14171D")
    static let panelAlt = Color(hex: "101319")
    static let cardStroke = Color.white.opacity(0.08)
    static let secondaryText = Color(hex: "98A2B3")
    static let tertiaryText = Color(hex: "677389")
    static let favorable = Color(hex: "22C55E")
    static let normal = Color(hex: "F59E0B")
    static let unfavorable = Color(hex: "EF4444")
    static let neutral = Color(hex: "CBD5E1")
    static let accent = Color(hex: "7ED2C3")
    static let action = Color(hex: "38BDF8")
}

extension PressureTone {
    var tint: Color {
        switch self {
        case .favorable:
            return RidePressurePalette.favorable
        case .normal:
            return RidePressurePalette.normal
        case .unfavorable:
            return RidePressurePalette.unfavorable
        case .neutral:
            return RidePressurePalette.neutral
        }
    }

    var softFill: Color {
        switch self {
        case .favorable:
            return Color(hex: "0F221D")
        case .normal:
            return Color(hex: "241C10")
        case .unfavorable:
            return Color(hex: "2B1417")
        case .neutral:
            return Color(hex: "171B22")
        }
    }

    var softStroke: Color {
        switch self {
        case .favorable:
            return RidePressurePalette.favorable.opacity(0.5)
        case .normal:
            return RidePressurePalette.normal.opacity(0.5)
        case .unfavorable:
            return RidePressurePalette.unfavorable.opacity(0.5)
        case .neutral:
            return Color(hex: "64748B").opacity(0.5)
        }
    }
}

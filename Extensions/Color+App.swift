import SwiftUI
import AppKit

// MARK: - App Color Palette
extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1.0
        )
    }
}

extension Color {
    private static func dynamic(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(hex: dark)
                : NSColor(hex: light)
        }))
    }

    static let appBackground = dynamic(light: "F5F7FA", dark: "0A1226")
    static let appSecondary = dynamic(light: "FFFFFF", dark: "0E1A33")
    static let appAccent = dynamic(light: "E4E9F2", dark: "13224A")
    // AppHighlight ve text renkleri tema değişince de aynı kalabilir veya uyarlanabilir
    // Şimdilik highlight'ı sabit tutalım, textleri uyarlayalım
    static let appHighlight = Color(hex: "003999") 
    static let appHighlightText = dynamic(light: "003999", dark: "C8D8FF")
    static let appControlDefault = dynamic(light: "D1D9E6", dark: "0C328C")
    static let appControlActive = Color(hex: "448AFF")
    static let appTextPrimary = dynamic(light: "1A202C", dark: "E9F0FF")
    static let appTextSecondary = dynamic(light: "718096", dark: "B8C6E6")
    static let appDivider = dynamic(light: "E2E8F0", dark: "1B2B55")
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

extension NSColor {
    static let appBackground = NSColor(Color.appBackground)
    static let appSecondary = NSColor(Color.appSecondary)
    static let appAccent = NSColor(Color.appAccent)
    static let appHighlight = NSColor(Color.appHighlight)
    static let appHighlightText = NSColor(Color.appHighlightText)
    static let appControlDefault = NSColor(Color.appControlDefault)
    static let appControlActive = NSColor(Color.appControlActive)
    static let appTextPrimary = NSColor(Color.appTextPrimary)
    static let appTextSecondary = NSColor(Color.appTextSecondary)
    static let appDivider = NSColor(Color.appDivider)
}

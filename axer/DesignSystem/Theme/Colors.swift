import SwiftUI

extension Color {
    static let axerPrimary = Color("Primary")
    static let axerPrimaryLight = Color("PrimaryLight")
    static let axerPrimaryDark = Color("PrimaryDark")
    static let axerBackground = Color("Background")
    static let axerSurface = Color("Surface")
    static let axerTextPrimary = Color("TextPrimary")
    static let axerTextSecondary = Color("TextSecondary")
    static let axerSuccess = Color("Success")
    static let axerWarning = Color("Warning")
    static let axerError = Color("Error")
}

struct AxerColors {
    static let primary = Color(hex: "2563EB")         // Blue 600
    static let primaryLight = Color(hex: "3B82F6")    // Blue 500
    static let primaryDark = Color(hex: "1D4ED8")     // Blue 700
    static let background = Color(hex: "F8FAFC")      // Slate 50
    static let surface = Color.white
    static let textPrimary = Color(hex: "1E293B")     // Slate 800
    static let textSecondary = Color(hex: "64748B")   // Slate 500
    static let success = Color(hex: "22C55E")         // Green 500
    static let warning = Color(hex: "F59E0B")         // Amber 500
    static let error = Color(hex: "EF4444")           // Red 500
    static let border = Color(hex: "E2E8F0")          // Slate 200
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

import SwiftUI
import UIKit

// MARK: - Adaptive Colors for Dark Mode

struct AxerColors {
    // MARK: - Primary Colors
    static let primary = Color(light: "0D47A1", dark: "60A5FA")           // Blue
    static let primaryLight = Color(light: "E3F2FD", dark: "1E3A5F")      // Light blue bg
    static let primaryDark = Color(light: "0A3470", dark: "93C5FD")       // Darker blue

    // MARK: - Background Colors
    static let background = Color(light: "F8FAFC", dark: "0F172A")        // Main background
    static let surface = Color(light: "FFFFFF", dark: "1E293B")           // Cards, sheets
    static let surfaceSecondary = Color(light: "F1F5F9", dark: "334155")  // Secondary surface

    // MARK: - Text Colors
    static let textPrimary = Color(light: "0D2137", dark: "F1F5F9")       // Main text
    static let textSecondary = Color(light: "64748B", dark: "94A3B8")     // Secondary text
    static let textTertiary = Color(light: "94A3B8", dark: "64748B")      // Muted text
    static let textInverse = Color(light: "FFFFFF", dark: "0F172A")       // Text on primary

    // MARK: - Border Colors
    static let border = Color(light: "E2E8F0", dark: "334155")            // Default border
    static let borderLight = Color(light: "F1F5F9", dark: "1E293B")       // Subtle border
    static let divider = Color(light: "E2E8F0", dark: "334155")           // Dividers

    // MARK: - Status Colors (same in both modes, high contrast)
    static let success = Color(light: "16A34A", dark: "22C55E")           // Green
    static let successLight = Color(light: "DCFCE7", dark: "14532D")      // Green bg
    static let warning = Color(light: "D97706", dark: "FBBF24")           // Amber
    static let warningLight = Color(light: "FEF3C7", dark: "451A03")      // Amber bg
    static let error = Color(light: "DC2626", dark: "F87171")             // Red
    static let errorLight = Color(light: "FEE2E2", dark: "450A0A")        // Red bg
    static let info = Color(light: "2563EB", dark: "60A5FA")              // Blue
    static let infoLight = Color(light: "DBEAFE", dark: "1E3A8A")         // Blue bg

    // MARK: - Order Status Colors
    static let statusReceived = Color(light: "64748B", dark: "94A3B8")    // Gray
    static let statusDiagnosing = Color(light: "D97706", dark: "FBBF24")  // Amber
    static let statusQuoted = Color(light: "7C3AED", dark: "A78BFA")      // Purple
    static let statusApproved = Color(light: "2563EB", dark: "60A5FA")    // Blue
    static let statusInRepair = Color(light: "EA580C", dark: "FB923C")    // Orange
    static let statusReady = Color(light: "16A34A", dark: "22C55E")       // Green
    static let statusDelivered = Color(light: "0D9488", dark: "2DD4BF")   // Teal

    // MARK: - Interactive Colors
    static let buttonPrimary = Color(light: "0D47A1", dark: "2563EB")
    static let buttonPrimaryPressed = Color(light: "0A3470", dark: "1D4ED8")
    static let buttonSecondary = Color(light: "E3F2FD", dark: "1E3A5F")
    static let buttonDestructive = Color(light: "DC2626", dark: "EF4444")

    // MARK: - Accent Colors
    static let accent = Color(light: "00BCD4", dark: "22D3EE")             // Cyan/Teal accent
    static let accentLight = Color(light: "E0F7FA", dark: "164E63")        // Cyan background

    // MARK: - Disabled/Muted Colors
    static let disabled = Color(light: "CBD5E1", dark: "475569")           // Disabled state
    static let muted = Color(light: "94A3B8", dark: "64748B")              // Muted elements

    // MARK: - Brand Colors (external services)
    static let whatsapp = Color(light: "25D366", dark: "25D366")           // WhatsApp green

    // MARK: - Gradient Colors
    static let gradientStart = Color(light: "0D47A1", dark: "1E3A8A")
    static let gradientMiddle = Color(light: "1565C0", dark: "1E40AF")
    static let gradientEnd = Color(light: "1976D2", dark: "2563EB")

    // MARK: - Overlay Colors
    static let overlay = Color(light: "000000", dark: "000000").opacity(0.5)
    static let shimmer = Color(light: "F1F5F9", dark: "334155")
}

// MARK: - Color Extension for Adaptive Colors

extension Color {
    /// Creates an adaptive color that changes based on light/dark mode
    init(light: String, dark: String) {
        self.init(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }

    /// Original hex initializer
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

// MARK: - UIColor Extension

extension UIColor {
    convenience init(hex: String) {
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
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}

// MARK: - Legacy Named Colors (for Asset Catalog compatibility)

extension Color {
    static let axerPrimary = AxerColors.primary
    static let axerPrimaryLight = AxerColors.primaryLight
    static let axerPrimaryDark = AxerColors.primaryDark
    static let axerBackground = AxerColors.background
    static let axerSurface = AxerColors.surface
    static let axerTextPrimary = AxerColors.textPrimary
    static let axerTextSecondary = AxerColors.textSecondary
    static let axerSuccess = AxerColors.success
    static let axerWarning = AxerColors.warning
    static let axerError = AxerColors.error
}

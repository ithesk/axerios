import SwiftUI

struct AxerTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let title1 = Font.system(size: 28, weight: .bold, design: .default)
    static let title2 = Font.system(size: 22, weight: .bold, design: .default)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let callout = Font.system(size: 16, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
}

extension View {
    func axerLargeTitle() -> some View {
        self.font(AxerTypography.largeTitle)
            .foregroundColor(AxerColors.textPrimary)
    }

    func axerTitle1() -> some View {
        self.font(AxerTypography.title1)
            .foregroundColor(AxerColors.textPrimary)
    }

    func axerTitle2() -> some View {
        self.font(AxerTypography.title2)
            .foregroundColor(AxerColors.textPrimary)
    }

    func axerBody() -> some View {
        self.font(AxerTypography.body)
            .foregroundColor(AxerColors.textPrimary)
    }

    func axerCaption() -> some View {
        self.font(AxerTypography.caption1)
            .foregroundColor(AxerColors.textSecondary)
    }
}

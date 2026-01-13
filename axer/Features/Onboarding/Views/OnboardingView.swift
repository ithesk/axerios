import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) var dismiss

    @State private var currentPage = 0
    @State private var currency = "DOP"
    @State private var orderPrefix = "ORD"
    @State private var isLoading = false

    private let currencies = ["DOP", "USD", "EUR", "MXN", "COP"]

    var body: some View {
        ZStack {
            AxerColors.surface
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    configPage.tag(1)
                    readyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index == currentPage ? AxerColors.primary : AxerColors.border)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 24)

                // Button
                Button {
                    handleButtonTap()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AxerColors.accent))
                        }
                        Text(buttonTitle)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(AxerColors.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AxerColors.textPrimary)
                    .cornerRadius(28)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Welcome Page
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(AxerColors.success)

            VStack(spacing: 12) {
                Text(L10n.Onboarding.createdTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AxerColors.textPrimary)

                Text(L10n.Onboarding.createdSubtitle(sessionStore.workshop?.name ?? ""))
                    .font(.system(size: 16))
                    .foregroundColor(AxerColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Config Page
    private var configPage: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 50))
                    .foregroundColor(AxerColors.primary)

                Text(L10n.Onboarding.basicConfig)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AxerColors.textPrimary)

                Text(L10n.Onboarding.changeLater)
                    .font(.system(size: 16))
                    .foregroundColor(AxerColors.textSecondary)
            }

            VStack(spacing: 20) {
                // Currency picker
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Onboarding.currency)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AxerColors.textSecondary)

                    HStack {
                        Image(systemName: "dollarsign.circle")
                            .foregroundColor(AxerColors.textSecondary)
                        Picker("Moneda", selection: $currency) {
                            ForEach(currencies, id: \.self) { curr in
                                Text(curr).tag(curr)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AxerColors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(AxerColors.background)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AxerColors.border, lineWidth: 1)
                    )
                }

                // Order prefix
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Onboarding.orderPrefix)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AxerColors.textSecondary)

                    AxerTextField(
                        placeholder: "Ej: ORD, REP, SRV",
                        text: $orderPrefix,
                        icon: "number",
                        autocapitalization: .characters
                    )

                    Text(L10n.Onboarding.prefixPreview(orderPrefix))
                        .font(.system(size: 13))
                        .foregroundColor(AxerColors.textTertiary)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Ready Page
    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "rocket.fill")
                .font(.system(size: 80))
                .foregroundColor(AxerColors.primary)

            VStack(spacing: 12) {
                Text(L10n.Onboarding.allSetTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AxerColors.textPrimary)

                Text(L10n.Onboarding.allSetSubtitle)
                    .font(.system(size: 16))
                    .foregroundColor(AxerColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Button
    private var buttonTitle: String {
        switch currentPage {
        case 0: return L10n.Common.continue
        case 1: return L10n.Common.save
        case 2: return L10n.Onboarding.start
        default: return L10n.Common.continue
        }
    }

    private func handleButtonTap() {
        switch currentPage {
        case 0:
            withAnimation { currentPage = 1 }
        case 1:
            Task { await saveConfiguration() }
        case 2:
            Task { await finishOnboarding() }
        default:
            break
        }
    }

    private func saveConfiguration() async {
        isLoading = true
        do {
            try await sessionStore.updateWorkshopConfig(currency: currency, orderPrefix: orderPrefix)
            withAnimation { currentPage = 2 }
        } catch {
            // Silently fail, can configure later
            withAnimation { currentPage = 2 }
        }
        isLoading = false
    }

    private func finishOnboarding() async {
        dismiss()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(SessionStore())
}

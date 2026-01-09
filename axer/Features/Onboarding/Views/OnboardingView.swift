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
            Color.white
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
                            .fill(index == currentPage ? Color(hex: "0D47A1") : Color(hex: "E2E8F0"))
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
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00BCD4")))
                        }
                        Text(buttonTitle)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "00BCD4"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "0D2137"))
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
                .foregroundColor(Color(hex: "22C55E"))

            VStack(spacing: 12) {
                Text("Taller Creado!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))

                Text("Tu taller \(sessionStore.workshop?.name ?? "") esta listo. Vamos a configurar algunas cosas basicas.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "64748B"))
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
                    .foregroundColor(Color(hex: "0D47A1"))

                Text("Configuracion Basica")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))

                Text("Puedes cambiar esto despues")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "64748B"))
            }

            VStack(spacing: 20) {
                // Currency picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Moneda")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "64748B"))

                    HStack {
                        Image(systemName: "dollarsign.circle")
                            .foregroundColor(Color(hex: "64748B"))
                        Picker("Moneda", selection: $currency) {
                            ForEach(currencies, id: \.self) { curr in
                                Text(curr).tag(curr)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color(hex: "0D2137"))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(Color(hex: "F8FAFC"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
                    )
                }

                // Order prefix
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prefijo de Ordenes")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "64748B"))

                    AxerTextField(
                        placeholder: "Ej: ORD, REP, SRV",
                        text: $orderPrefix,
                        icon: "number",
                        autocapitalization: .characters
                    )

                    Text("Las ordenes se veran como: \(orderPrefix)-001")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "94A3B8"))
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
                .foregroundColor(Color(hex: "0D47A1"))

            VStack(spacing: 12) {
                Text("Todo Listo!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))

                Text("Tu taller esta configurado y listo para comenzar a recibir ordenes.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "64748B"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Button
    private var buttonTitle: String {
        switch currentPage {
        case 0: return "Continuar"
        case 1: return "Guardar"
        case 2: return "Comenzar"
        default: return "Continuar"
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

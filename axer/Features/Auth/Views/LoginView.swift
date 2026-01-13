import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var networkMonitor: NetworkMonitor

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            AxerColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header con boton volver
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AxerColors.textPrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 32) {
                        // Titulo
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.Login.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(AxerColors.textPrimary)

                            Text(L10n.Login.subtitle)
                                .font(.system(size: 16))
                                .foregroundColor(AxerColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 32)

                        // Formulario
                        VStack(spacing: 16) {
                            AxerTextField(
                                placeholder: L10n.Login.emailPlaceholder,
                                text: $email,
                                icon: "envelope",
                                keyboardType: .emailAddress,
                                autocapitalization: .never
                            )

                            AxerTextField(
                                placeholder: L10n.Login.passwordPlaceholder,
                                text: $password,
                                isSecure: true,
                                icon: "lock"
                            )
                        }

                        // Boton login
                        Button {
                            Task { await login() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AxerColors.textInverse))
                                }
                                Text(L10n.Login.button)
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(AxerColors.textInverse)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AxerColors.buttonPrimary)
                            .cornerRadius(28)
                        }
                        .disabled(!isFormValid || isLoading)
                        .opacity(isFormValid ? 1 : 0.6)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .alert(L10n.Common.error, isPresented: $showError) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }

    private func login() async {
        isLoading = true
        do {
            try await sessionStore.signIn(email: email, password: password)
            dismiss()
        } catch {
            errorMessage = L10n.Login.errorInvalidCredentials
            showError = true
        }
        isLoading = false
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionStore())
        .environmentObject(NetworkMonitor())
}

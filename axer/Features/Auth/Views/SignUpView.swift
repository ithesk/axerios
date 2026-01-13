import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionStore: SessionStore

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            AxerColors.surface
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
                            Text(L10n.SignUp.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(AxerColors.textPrimary)

                            Text(L10n.SignUp.subtitle)
                                .font(.system(size: 16))
                                .foregroundColor(AxerColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 32)

                        // Formulario
                        VStack(spacing: 16) {
                            AxerTextField(
                                placeholder: "Nombre completo",
                                text: $fullName,
                                icon: "person",
                                autocapitalization: .words
                            )

                            AxerTextField(
                                placeholder: "Email",
                                text: $email,
                                icon: "envelope",
                                keyboardType: .emailAddress,
                                autocapitalization: .never
                            )

                            AxerTextField(
                                placeholder: "Contrasena",
                                text: $password,
                                isSecure: true,
                                icon: "lock"
                            )
                        }

                        // Boton crear cuenta
                        Button {
                            Task { await signUp() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AxerColors.accent))
                                }
                                Text(L10n.SignUp.button)
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(AxerColors.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AxerColors.textPrimary)
                            .cornerRadius(28)
                        }
                        .disabled(!isFormValid || isLoading)
                        .opacity(isFormValid ? 1 : 0.6)

                        // Terminos
                        Text(L10n.SignUp.termsText)
                            .font(.system(size: 13))
                            .foregroundColor(AxerColors.textTertiary)
                            .multilineTextAlignment(.center)
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
        !fullName.isEmpty && !email.isEmpty && !password.isEmpty && email.contains("@") && password.count >= 6
    }

    private func signUp() async {
        isLoading = true
        do {
            try await sessionStore.signUp(email: email, password: password)
            dismiss()
        } catch {
            errorMessage = L10n.Error.creatingAccount
            showError = true
        }
        isLoading = false
    }
}

#Preview {
    SignUpView()
        .environmentObject(SessionStore())
}

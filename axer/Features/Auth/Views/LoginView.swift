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
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header con boton volver
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(hex: "0D2137"))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 32) {
                        // Titulo
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Iniciar Sesion")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: "0D2137"))

                            Text("Ingresa tus datos para continuar")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "64748B"))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 32)

                        // Formulario
                        VStack(spacing: 16) {
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

                        // Boton login
                        Button {
                            Task { await login() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00BCD4")))
                                }
                                Text("Iniciar Sesion")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "00BCD4"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(hex: "0D2137"))
                            .cornerRadius(28)
                        }
                        .disabled(!isFormValid || isLoading)
                        .opacity(isFormValid ? 1 : 0.6)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
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
            errorMessage = "Credenciales incorrectas. Intenta de nuevo."
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

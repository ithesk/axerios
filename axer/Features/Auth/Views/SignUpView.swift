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
                            Text("Crear Cuenta")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: "0D2137"))

                            Text("Completa tus datos para comenzar")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "64748B"))
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
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00BCD4")))
                                }
                                Text("Crear Cuenta")
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

                        // Terminos
                        Text("Al crear una cuenta, aceptas nuestros Terminos de Servicio y Politica de Privacidad")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "94A3B8"))
                            .multilineTextAlignment(.center)
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
        !fullName.isEmpty && !email.isEmpty && !password.isEmpty && email.contains("@") && password.count >= 6
    }

    private func signUp() async {
        isLoading = true
        do {
            try await sessionStore.signUp(email: email, password: password)
            dismiss()
        } catch {
            errorMessage = "No se pudo crear la cuenta. Intenta de nuevo."
            showError = true
        }
        isLoading = false
    }
}

#Preview {
    SignUpView()
        .environmentObject(SessionStore())
}

import SwiftUI

struct SignUpWorkshopView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionStore: SessionStore

    @State private var currentStep = 0
    @State private var workshopName = ""
    @State private var workshopPhone = ""
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showOnboarding = false
    @State private var showEmailVerification = false

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Progress indicator
                progressIndicator

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        if currentStep == 0 {
                            workshopStepView
                        } else {
                            accountStepView
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                }

                // Bottom button
                bottomButton
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .fullScreenCover(isPresented: $showEmailVerification) {
            EmailVerificationView(email: email)
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button {
                if currentStep > 0 {
                    withAnimation { currentStep -= 1 }
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: "0D2137"))
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<2) { index in
                Capsule()
                    .fill(index <= currentStep ? Color(hex: "0D47A1") : Color(hex: "E2E8F0"))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - Step 1: Workshop Info
    private var workshopStepView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Datos del Taller")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))

                Text("Ingresa la informacion de tu negocio")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "64748B"))
            }

            VStack(spacing: 16) {
                AxerTextField(
                    placeholder: "Nombre del taller",
                    text: $workshopName,
                    icon: "building.2"
                )

                AxerTextField(
                    placeholder: "Telefono (opcional)",
                    text: $workshopPhone,
                    icon: "phone",
                    keyboardType: .phonePad
                )
            }
        }
    }

    // MARK: - Step 2: Account Info
    private var accountStepView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tu Cuenta")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))

                Text("Crea tu cuenta de administrador")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "64748B"))
            }

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

            Text("La contrasena debe tener al menos 6 caracteres")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "94A3B8"))
        }
    }

    // MARK: - Bottom Button
    private var bottomButton: some View {
        VStack(spacing: 16) {
            Button {
                if currentStep == 0 {
                    withAnimation { currentStep = 1 }
                } else {
                    Task { await createWorkshopAndAccount() }
                }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00BCD4")))
                    }
                    Text(currentStep == 0 ? "Continuar" : "Crear Taller")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(Color(hex: "00BCD4"))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(hex: "0D2137"))
                .cornerRadius(28)
            }
            .disabled(!isCurrentStepValid || isLoading)
            .opacity(isCurrentStepValid ? 1 : 0.6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Validation
    private var isCurrentStepValid: Bool {
        if currentStep == 0 {
            return !workshopName.isEmpty
        } else {
            return !fullName.isEmpty && !email.isEmpty && email.contains("@") && password.count >= 6
        }
    }

    // MARK: - Create Workshop and Account
    private func createWorkshopAndAccount() async {
        isLoading = true

        do {
            try await sessionStore.signUpWithPendingWorkshop(
                workshopName: workshopName,
                workshopPhone: workshopPhone.isEmpty ? nil : workshopPhone,
                fullName: fullName,
                email: email,
                password: password
            )

            // Show email verification screen
            // The workshop will be created after email is verified
            showEmailVerification = true

        } catch {
            errorMessage = "No se pudo crear la cuenta. Intenta de nuevo."
            showError = true
        }

        isLoading = false
    }
}

#Preview {
    SignUpWorkshopView()
        .environmentObject(SessionStore())
}

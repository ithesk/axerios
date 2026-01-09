import SwiftUI

struct JoinWorkshopView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionStore: SessionStore

    @State private var inviteCode = ""
    @State private var isValidating = false
    @State private var validation: InviteValidation?
    @State private var showError = false
    @State private var errorMessage = ""

    // For creating account with invite
    @State private var showCreateAccount = false
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()

                if showCreateAccount {
                    createAccountView
                } else if let valid = validation, valid.valid {
                    inviteValidView(validation: valid)
                } else {
                    enterCodeView
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if showCreateAccount {
                            showCreateAccount = false
                        } else if validation != nil {
                            validation = nil
                            inviteCode = ""
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: showCreateAccount || validation != nil ? "arrow.left" : "xmark")
                            .foregroundColor(Color(hex: "0D2137"))
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var navigationTitle: String {
        if showCreateAccount {
            return "Crear Cuenta"
        } else if validation != nil {
            return "Confirmar"
        }
        return "Unirse a Taller"
    }

    // MARK: - Enter Code View
    private var enterCodeView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "E3F2FD"))
                    .frame(width: 100, height: 100)

                Image(systemName: "ticket")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "0D47A1"))
            }

            // Text
            VStack(spacing: 8) {
                Text("Codigo de Invitacion")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))

                Text("Ingresa el codigo que te compartio el administrador del taller.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "64748B"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Code input
            TextField("", text: $inviteCode)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding()
                .frame(height: 64)
                .background(Color(hex: "F8FAFC"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
                )
                .padding(.horizontal, 48)

            Spacer()

            // Validate button
            Button {
                Task { await validateCode() }
            } label: {
                HStack {
                    if isValidating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00BCD4")))
                    }
                    Text("Verificar Codigo")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(Color(hex: "00BCD4"))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(inviteCode.count >= 8 ? Color(hex: "0D2137") : Color(hex: "CBD5E1"))
                .cornerRadius(28)
            }
            .disabled(inviteCode.count < 8 || isValidating)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Invite Valid View
    private func inviteValidView(validation: InviteValidation) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(Color(hex: "D1FAE5"))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "22C55E"))
            }

            // Info
            VStack(spacing: 16) {
                Text("Invitacion Valida!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))

                VStack(spacing: 8) {
                    Text("Te uniras a:")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "64748B"))

                    Text(validation.workshopName ?? "Taller")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "0D47A1"))

                    Text("como \(validation.role ?? "miembro")")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "64748B"))
                }
            }

            Spacer()

            // Continue button
            Button {
                showCreateAccount = true
            } label: {
                Text("Continuar")
                    .font(.system(size: 17, weight: .semibold))
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

    // MARK: - Create Account View
    private var createAccountView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Crea tu Cuenta")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "0D2137"))

                    Text("Ingresa tus datos para unirte al taller")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "64748B"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)

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
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
                    .frame(height: 40)

                // Create button
                Button {
                    Task { await createAccountAndJoin() }
                } label: {
                    HStack {
                        if isCreatingAccount {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00BCD4")))
                        }
                        Text("Crear Cuenta y Unirme")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "00BCD4"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isFormValid ? Color(hex: "0D2137") : Color(hex: "CBD5E1"))
                    .cornerRadius(28)
                }
                .disabled(!isFormValid || isCreatingAccount)
            }
            .padding(.horizontal, 24)
        }
    }

    private var isFormValid: Bool {
        !fullName.isEmpty && !email.isEmpty && email.contains("@") && password.count >= 6
    }

    // MARK: - Actions
    private func validateCode() async {
        isValidating = true

        if let result = await TeamViewModel.validateInvite(token: inviteCode) {
            if result.valid {
                withAnimation {
                    validation = result
                }
            } else {
                errorMessage = "Codigo invalido o expirado"
                showError = true
            }
        } else {
            errorMessage = "No se pudo verificar el codigo"
            showError = true
        }

        isValidating = false
    }

    private func createAccountAndJoin() async {
        isCreatingAccount = true

        do {
            // 1. Create account
            let authResponse = try await SupabaseClient.shared.client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )

            print("✅ Usuario creado: \(authResponse.user.id)")

            // 2. Accept invite (this updates the profile with workshop_id)
            let accepted = await TeamViewModel.acceptInvite(token: inviteCode)

            if accepted {
                print("✅ Invitacion aceptada")
                // Reload user data
                await sessionStore.loadUserData()
                dismiss()
            } else {
                errorMessage = "No se pudo aceptar la invitacion"
                showError = true
            }

        } catch {
            errorMessage = "Error creando cuenta: \(error.localizedDescription)"
            showError = true
        }

        isCreatingAccount = false
    }
}

#Preview {
    JoinWorkshopView()
        .environmentObject(SessionStore())
}

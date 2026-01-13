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
                AxerColors.surface
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
                            .foregroundColor(AxerColors.textPrimary)
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
            return L10n.JoinWorkshop.createAccount
        } else if validation != nil {
            return L10n.JoinWorkshop.confirm
        }
        return L10n.JoinWorkshop.title
    }

    // MARK: - Enter Code View
    private var enterCodeView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(AxerColors.primaryLight)
                    .frame(width: 100, height: 100)

                Image(systemName: "ticket")
                    .font(.system(size: 40))
                    .foregroundColor(AxerColors.primary)
            }

            // Text
            VStack(spacing: 8) {
                Text(L10n.JoinWorkshop.codeTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AxerColors.textPrimary)

                Text(L10n.JoinWorkshop.codeSubtitle)
                    .font(.system(size: 16))
                    .foregroundColor(AxerColors.textSecondary)
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
                .background(AxerColors.background)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AxerColors.border, lineWidth: 1)
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
                            .progressViewStyle(CircularProgressViewStyle(tint: AxerColors.accent))
                    }
                    Text(L10n.JoinWorkshop.verifyButton)
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(AxerColors.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(inviteCode.count >= 8 ? AxerColors.textPrimary : AxerColors.disabled)
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
                    .fill(AxerColors.successLight)
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(AxerColors.success)
            }

            // Info
            VStack(spacing: 16) {
                Text(L10n.JoinWorkshop.validTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AxerColors.textPrimary)

                VStack(spacing: 8) {
                    Text(L10n.JoinWorkshop.joiningTo)
                        .font(.system(size: 15))
                        .foregroundColor(AxerColors.textSecondary)

                    Text(validation.workshopName ?? "Taller")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AxerColors.primary)

                    Text(L10n.JoinWorkshop.asMember(validation.role ?? "miembro"))
                        .font(.system(size: 15))
                        .foregroundColor(AxerColors.textSecondary)
                }
            }

            Spacer()

            // Continue button
            Button {
                showCreateAccount = true
            } label: {
                Text(L10n.Common.continue)
                    .font(.system(size: 17, weight: .semibold))
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

    // MARK: - Create Account View
    private var createAccountView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.JoinWorkshop.createAccountTitle)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AxerColors.textPrimary)

                    Text(L10n.JoinWorkshop.createAccountSubtitle)
                        .font(.system(size: 16))
                        .foregroundColor(AxerColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)

                VStack(spacing: 16) {
                    AxerTextField(
                        placeholder: L10n.SignUp.fullnamePlaceholder,
                        text: $fullName,
                        icon: "person",
                        autocapitalization: .words
                    )

                    AxerTextField(
                        placeholder: L10n.SignUp.emailPlaceholder,
                        text: $email,
                        icon: "envelope",
                        keyboardType: .emailAddress,
                        autocapitalization: .never
                    )

                    AxerTextField(
                        placeholder: L10n.SignUp.passwordPlaceholder,
                        text: $password,
                        isSecure: true,
                        icon: "lock"
                    )
                }

                Text(L10n.SignUp.passwordHint)
                    .font(.system(size: 13))
                    .foregroundColor(AxerColors.textTertiary)
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
                                .progressViewStyle(CircularProgressViewStyle(tint: AxerColors.accent))
                        }
                        Text(L10n.JoinWorkshop.createAndJoin)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(AxerColors.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isFormValid ? AxerColors.textPrimary : AxerColors.disabled)
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
                errorMessage = L10n.JoinWorkshop.invalidCode
                showError = true
            }
        } else {
            errorMessage = L10n.JoinWorkshop.verifyError
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
                errorMessage = L10n.JoinWorkshop.acceptError
                showError = true
            }

        } catch {
            errorMessage = L10n.JoinWorkshop.createError
            showError = true
        }

        isCreatingAccount = false
    }
}

#Preview {
    JoinWorkshopView()
        .environmentObject(SessionStore())
}

import SwiftUI

struct EmailVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionStore: SessionStore

    let email: String

    @State private var isChecking = false
    @State private var showResendSuccess = false

    var body: some View {
        ZStack {
            AxerColors.surface
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(AxerColors.primaryLight)
                        .frame(width: 120, height: 120)

                    Image(systemName: "envelope.badge")
                        .font(.system(size: 50))
                        .foregroundColor(AxerColors.primary)
                }

                // Text
                VStack(spacing: 12) {
                    Text(L10n.EmailVerification.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AxerColors.textPrimary)

                    Text(L10n.EmailVerification.sentTo)
                        .font(.system(size: 16))
                        .foregroundColor(AxerColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Text(email)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AxerColors.primary)

                    Text(L10n.EmailVerification.checkInbox)
                        .font(.system(size: 14))
                        .foregroundColor(AxerColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Buttons
                VStack(spacing: 16) {
                    // Resend button
                    Button {
                        Task { await resendVerificationEmail() }
                    } label: {
                        Text(L10n.EmailVerification.resend)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AxerColors.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AxerColors.primaryLight)
                            .cornerRadius(28)
                    }

                    // Back button
                    Button {
                        // Clear pending data and dismiss
                        sessionStore.clearPendingWorkshopData()
                        dismiss()
                    } label: {
                        Text(L10n.EmailVerification.backHome)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AxerColors.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .alert(L10n.EmailVerification.resentTitle, isPresented: $showResendSuccess) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(L10n.EmailVerification.resentSuccess)
        }
    }

    private func resendVerificationEmail() async {
        do {
            try await sessionStore.resendVerificationEmail(to: email)
            showResendSuccess = true
        } catch {
            // Silently fail, user can try again
        }
    }
}

#Preview {
    EmailVerificationView(email: "test@example.com")
        .environmentObject(SessionStore())
}

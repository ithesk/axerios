import SwiftUI

struct EmailVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionStore: SessionStore

    let email: String

    @State private var isChecking = false
    @State private var showResendSuccess = false

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "E3F2FD"))
                        .frame(width: 120, height: 120)

                    Image(systemName: "envelope.badge")
                        .font(.system(size: 50))
                        .foregroundColor(Color(hex: "0D47A1"))
                }

                // Text
                VStack(spacing: 12) {
                    Text("Verifica tu Email")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "0D2137"))

                    Text("Hemos enviado un enlace de verificacion a:")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "64748B"))
                        .multilineTextAlignment(.center)

                    Text(email)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "0D47A1"))

                    Text("Revisa tu bandeja de entrada y haz clic en el enlace para continuar.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "94A3B8"))
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
                        Text("Reenviar Email")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(hex: "0D47A1"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(hex: "E3F2FD"))
                            .cornerRadius(28)
                    }

                    // Back button
                    Button {
                        // Clear pending data and dismiss
                        sessionStore.clearPendingWorkshopData()
                        dismiss()
                    } label: {
                        Text("Volver al Inicio")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(hex: "64748B"))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .alert("Email Enviado", isPresented: $showResendSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Hemos reenviado el email de verificacion.")
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

import SwiftUI

struct WelcomeView: View {
    @State private var showLogin = false
    @State private var showSignUp = false
    @State private var showJoinWorkshop = false

    var body: some View {
        ZStack {
            // Fondo gradiente azul
            LinearGradient(
                gradient: Gradient(colors: [
                    AxerColors.gradientStart,
                    AxerColors.gradientMiddle,
                    AxerColors.gradientEnd
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Area superior
                Spacer()

                // Card blanco inferior
                VStack(alignment: .leading, spacing: 16) {
                    // Nombre
                    Text(L10n.Welcome.appName)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AxerColors.primary)

                    // Slogan
                    Text(L10n.Welcome.tagline)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(AxerColors.primaryDark)
                        .lineSpacing(4)

                    Spacer()
                        .frame(height: 12)

                    // Boton Crear Taller
                    Button {
                        showSignUp = true
                    } label: {
                        Text(L10n.Welcome.createWorkshop)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AxerColors.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AxerColors.textPrimary)
                            .cornerRadius(28)
                    }

                    // Boton Unirse a Taller
                    Button {
                        showJoinWorkshop = true
                    } label: {
                        Text(L10n.Welcome.haveInvite)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AxerColors.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AxerColors.primaryLight)
                            .cornerRadius(24)
                    }

                    // Boton Iniciar Sesion
                    Button {
                        showLogin = true
                    } label: {
                        Text(L10n.Welcome.haveAccount)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AxerColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 36)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.height * 0.46)
                .background(
                    VStack(spacing: 0) {
                        RoundedCorner(radius: 32, corners: [.topLeft, .topRight])
                            .fill(AxerColors.surface)
                        AxerColors.surface
                            .ignoresSafeArea(edges: .bottom)
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .fullScreenCover(isPresented: $showSignUp) {
            SignUpWorkshopView()
        }
        .fullScreenCover(isPresented: $showJoinWorkshop) {
            JoinWorkshopView()
        }
    }
}

// Helper para redondear solo esquinas superiores
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    WelcomeView()
}

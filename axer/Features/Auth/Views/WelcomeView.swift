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
                    Color(hex: "0D47A1"),
                    Color(hex: "1565C0"),
                    Color(hex: "1976D2")
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
                    Text("axer")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "0D47A1"))

                    // Slogan
                    Text("Juntos vamos a\norganizar tu taller")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color(hex: "1A237E"))
                        .lineSpacing(4)

                    Spacer()
                        .frame(height: 12)

                    // Boton Crear Taller
                    Button {
                        showSignUp = true
                    } label: {
                        Text("Crear mi Taller")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(hex: "00BCD4"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(hex: "0D2137"))
                            .cornerRadius(28)
                    }

                    // Boton Unirse a Taller
                    Button {
                        showJoinWorkshop = true
                    } label: {
                        Text("Tengo un codigo de invitacion")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "0D47A1"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(hex: "E3F2FD"))
                            .cornerRadius(24)
                    }

                    // Boton Iniciar Sesion
                    Button {
                        showLogin = true
                    } label: {
                        Text("Ya tengo cuenta")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "64748B"))
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
                            .fill(Color.white)
                        Color.white
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

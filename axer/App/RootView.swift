import SwiftUI

struct RootView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var router: Router

    var body: some View {
        Group {
            switch sessionStore.state {
            case .loading:
                SplashView()
            case .unauthenticated:
                WelcomeView()
            case .pendingEmailVerification:
                if let email = sessionStore.pendingEmail {
                    EmailVerificationView(email: email)
                } else {
                    WelcomeView()
                }
            case .authenticated:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: sessionStore.state)
    }
}

#Preview {
    RootView()
        .environmentObject(SessionStore())
        .environmentObject(Router())
        .environmentObject(NetworkMonitor())
}

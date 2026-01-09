import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    router.destination(for: route)
                }
        }
        .fullScreenCover(isPresented: $sessionStore.shouldShowOnboarding) {
            OnboardingView()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SessionStore())
        .environmentObject(Router())
        .environmentObject(NetworkMonitor())
}

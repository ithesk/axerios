import SwiftUI

@main
struct axerApp: App {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var router = Router()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionStore)
                .environmentObject(networkMonitor)
                .environmentObject(router)
                .task {
                    await sessionStore.initialize()
                }
                .onOpenURL { url in
                    // Handle deep link from email confirmation
                    Task {
                        await sessionStore.handleDeepLink(url: url)
                    }
                }
        }
    }
}

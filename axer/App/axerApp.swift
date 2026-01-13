import SwiftUI
import RollbarNotifier

@main
struct axerApp: App {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var router = Router()

    init() {
        configureRollbar()
    }

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

    private func configureRollbar() {
        #if DEBUG
        let environment = "development"
        #else
        let environment = "production"
        #endif

        let config = RollbarConfig.mutableConfig(
            withAccessToken: "d6b78c6c231c4c1cbe574c3124cab952",
            environment: environment
        )

        Rollbar.initWithConfiguration(config)
        Rollbar.infoMessage("Axer app started")
    }
}

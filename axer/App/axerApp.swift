import SwiftUI
import UIKit
import UserNotifications
import RollbarNotifier
import os

// MARK: - Push Notification Types

enum NotificationType: String {
    case orderStatus = "order_status"
    case orderAssigned = "order_assigned"
    case quoteResponse = "quote_response"
}

struct PushNotificationPayload {
    let type: NotificationType
    let orderId: UUID?
    let title: String
    let body: String

    init?(userInfo: [AnyHashable: Any]) {
        guard let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString) else {
            return nil
        }
        self.type = type
        self.title = userInfo["title"] as? String ?? ""
        self.body = userInfo["body"] as? String ?? ""
        if let orderIdString = userInfo["order_id"] as? String {
            self.orderId = UUID(uuidString: orderIdString)
        } else {
            self.orderId = nil
        }
    }
}

// MARK: - Push Notification Manager

@MainActor
final class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()

    private let supabase = SupabaseClient.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.axer", category: "Push")

    @Published private(set) var isPermissionGranted = false
    @Published private(set) var deviceToken: String?

    // Guardamos el userId para registrar el token cuando llegue
    private var pendingUserId: UUID?

    var onNotificationTapped: ((PushNotificationPayload) -> Void)?

    private init() {
        print("📱 [PUSH] PushNotificationManager initialized")
    }

    func requestPermission() async {
        print("📱 [PUSH] Requesting notification permission...")

        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            isPermissionGranted = granted

            print("📱 [PUSH] Permission granted: \(granted)")

            if granted {
                print("📱 [PUSH] Registering for remote notifications...")
                UIApplication.shared.registerForRemoteNotifications()
            } else {
                print("📱 [PUSH] Permission denied by user")
            }
        } catch {
            print("📱 [PUSH] ERROR requesting permission: \(error.localizedDescription)")
        }
    }

    func setDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        print("📱 [PUSH] ✅ Device token received: \(token.prefix(20))...")

        // Si hay un userId pendiente, registrar ahora
        if let userId = pendingUserId {
            print("📱 [PUSH] Found pending userId, registering token now...")
            Task {
                await registerTokenForUser(userId: userId)
            }
        }
    }

    func setDeviceTokenFailed(error: Error) {
        print("📱 [PUSH] ❌ Failed to get device token: \(error.localizedDescription)")
    }

    func registerTokenForUser(userId: UUID) async {
        print("📱 [PUSH] registerTokenForUser called for: \(userId.uuidString.prefix(8))...")

        // Guardar userId para cuando llegue el token
        self.pendingUserId = userId

        guard let token = deviceToken else {
            print("📱 [PUSH] ⚠️ No device token yet, will register when token arrives")
            return
        }

        print("📱 [PUSH] Saving token to Supabase...")

        do {
            let deviceName = UIDevice.current.name

            struct DeviceTokenInsert: Encodable {
                let user_id: String
                let token: String
                let platform: String
                let device_name: String
            }

            let insert = DeviceTokenInsert(
                user_id: userId.uuidString,
                token: token,
                platform: "ios",
                device_name: deviceName
            )

            try await supabase.client
                .from("device_tokens")
                .upsert(insert, onConflict: "user_id,token")
                .execute()

            print("📱 [PUSH] ✅ Token saved to Supabase successfully!")
            self.pendingUserId = nil // Clear pending

        } catch {
            print("📱 [PUSH] ❌ ERROR saving token: \(error.localizedDescription)")
        }
    }

    func unregisterTokenForUser(userId: UUID) async {
        guard let token = deviceToken else { return }

        print("📱 [PUSH] Unregistering token for user...")

        do {
            try await supabase.client
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("token", value: token)
                .execute()

            print("📱 [PUSH] ✅ Token unregistered")
        } catch {
            print("📱 [PUSH] ❌ ERROR unregistering: \(error.localizedDescription)")
        }
    }

    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        print("📱 [PUSH] Notification tapped: \(userInfo)")
        guard let payload = PushNotificationPayload(userInfo: userInfo) else {
            print("📱 [PUSH] Could not parse notification payload")
            return
        }
        print("📱 [PUSH] Notification type: \(payload.type.rawValue)")
        onNotificationTapped?(payload)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("📱 [PUSH] AppDelegate didFinishLaunching")
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("📱 [PUSH] ✅ didRegisterForRemoteNotifications - token received!")
        Task { @MainActor in
            PushNotificationManager.shared.setDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("📱 [PUSH] ❌ didFailToRegisterForRemoteNotifications: \(error.localizedDescription)")
        Task { @MainActor in
            PushNotificationManager.shared.setDeviceTokenFailed(error: error)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📱 [PUSH] Notification received in foreground")
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("📱 [PUSH] Notification tapped by user")
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            PushNotificationManager.shared.handleNotificationTap(userInfo: userInfo)
        }
        completionHandler()
    }
}

// MARK: - Main App

@main
struct axerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var router = Router()
    private var pushManager = PushNotificationManager.shared

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
                    configurePushNotificationNavigation()
                }
                .onOpenURL { url in
                    Task {
                        await sessionStore.handleDeepLink(url: url)
                    }
                }
                .onChange(of: sessionStore.state) { _, newState in
                    if case .authenticated = newState {
                        print("📱 [PUSH] User authenticated, requesting permission...")
                        Task {
                            await pushManager.requestPermission()
                            // Esperar un momento para que llegue el token
                            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 segundos
                            if let userId = sessionStore.user?.id {
                                await pushManager.registerTokenForUser(userId: userId)
                            }
                        }
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

    private func configurePushNotificationNavigation() {
        let router = self.router
        pushManager.onNotificationTapped = { payload in
            guard let orderId = payload.orderId else { return }
            Task { @MainActor in
                router.navigateToOrder(orderId: orderId)
            }
        }
    }
}

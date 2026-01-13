import SwiftUI

enum Route: Hashable {
    case home
    case profile
    case settings
    case team
    case orders
    case orderDetail(UUID)
    case customers
}

@MainActor
final class Router: ObservableObject {
    // Separate navigation paths for each tab
    @Published var homePath = NavigationPath()
    @Published var ordersPath = NavigationPath()
    @Published var customersPath = NavigationPath()
    @Published var settingsPath = NavigationPath()

    // For programmatic tab switching
    @Published var selectedTab: Tab?

    // Legacy support - maps to homePath
    var path: NavigationPath {
        get { homePath }
        set { homePath = newValue }
    }

    func navigate(to route: Route) {
        homePath.append(route)
    }

    func navigateInOrders(to route: Route) {
        ordersPath.append(route)
    }

    func navigateInCustomers(to route: Route) {
        customersPath.append(route)
    }

    func navigateInSettings(to route: Route) {
        settingsPath.append(route)
    }

    func pop() {
        guard !homePath.isEmpty else { return }
        homePath.removeLast()
    }

    func popToRoot() {
        homePath = NavigationPath()
    }

    func switchToTab(_ tab: Tab) {
        selectedTab = tab
    }

    @ViewBuilder
    func destination(for route: Route) -> some View {
        switch route {
        case .home:
            HomeView()
        case .profile:
            Text("Profile View")
        case .settings:
            SettingsView()
        case .team:
            TeamView()
        case .orders:
            OrdersListView()
        case .orderDetail(let orderId):
            OrderDetailView(orderId: orderId)
        case .customers:
            CustomersView()
        }
    }
}

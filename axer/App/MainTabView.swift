import SwiftUI

enum Tab: Int, CaseIterable {
    case home
    case orders
    case customers
    case settings

    var title: String {
        switch self {
        case .home: return "Inicio"
        case .orders: return "Órdenes"
        case .customers: return "Clientes"
        case .settings: return "Ajustes"
        }
    }

    var icon: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .orders: return "list.clipboard.fill"
        case .customers: return "person.2.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var sessionStore: SessionStore
    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationStack(path: $router.homePath) {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        router.destination(for: route)
                    }
            }
            .tabItem {
                Label(Tab.home.title, systemImage: Tab.home.icon)
            }
            .tag(Tab.home)

            // Orders Tab
            NavigationStack(path: $router.ordersPath) {
                OrdersListView()
                    .navigationDestination(for: Route.self) { route in
                        router.destination(for: route)
                    }
            }
            .tabItem {
                Label(Tab.orders.title, systemImage: Tab.orders.icon)
            }
            .tag(Tab.orders)

            // Customers Tab
            NavigationStack(path: $router.customersPath) {
                CustomersView()
                    .navigationDestination(for: Route.self) { route in
                        router.destination(for: route)
                    }
            }
            .tabItem {
                Label(Tab.customers.title, systemImage: Tab.customers.icon)
            }
            .tag(Tab.customers)

            // Settings Tab
            NavigationStack(path: $router.settingsPath) {
                SettingsView()
                    .navigationDestination(for: Route.self) { route in
                        router.destination(for: route)
                    }
            }
            .tabItem {
                Label(Tab.settings.title, systemImage: Tab.settings.icon)
            }
            .tag(Tab.settings)
        }
        .tint(AxerColors.primary)
        .fullScreenCover(isPresented: $sessionStore.shouldShowOnboarding) {
            OnboardingView()
        }
        .onChange(of: router.selectedTab) { _, newTab in
            if let tab = newTab {
                selectedTab = tab
                router.selectedTab = nil
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SessionStore())
        .environmentObject(Router())
        .environmentObject(NetworkMonitor())
}

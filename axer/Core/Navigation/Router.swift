import SwiftUI

enum Route: Hashable {
    case home
    case profile
    case settings
    case team
    case orders
    case orderDetail(UUID)
}

@MainActor
final class Router: ObservableObject {
    @Published var path = NavigationPath()

    func navigate(to route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }

    @ViewBuilder
    func destination(for route: Route) -> some View {
        switch route {
        case .home:
            HomeView()
        case .profile:
            Text("Profile View") // Placeholder for future implementation
        case .settings:
            Text("Settings View") // Placeholder for future implementation
        case .team:
            TeamView()
        case .orders:
            OrdersListView()
        case .orderDetail(let orderId):
            OrderDetailView(orderId: orderId)
        }
    }
}

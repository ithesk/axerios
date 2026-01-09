import SwiftUI

struct HomeView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var router: Router

    @StateObject private var ordersViewModel = OrdersViewModel()
    @State private var showLogoutAlert = false
    @State private var showNewOrder = false

    var body: some View {
        ZStack {
            AxerColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                OfflineBanner()

                ScrollView {
                    VStack(spacing: AxerSpacing.lg) {
                        welcomeHeader
                        quickStatsSection
                        menuSection
                        recentOrdersSection
                    }
                    .padding(AxerSpacing.md)
                    .padding(.bottom, 80)
                }
            }

            // Floating button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingButton
                }
            }
            .padding(20)
        }
        .navigationTitle("Inicio")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showLogoutAlert = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(AxerColors.textSecondary)
                }
            }
        }
        .alert("Cerrar Sesion", isPresented: $showLogoutAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Salir", role: .destructive) {
                Task {
                    try? await sessionStore.signOut()
                }
            }
        } message: {
            Text("Estas seguro que quieres cerrar sesion?")
        }
        .sheet(isPresented: $showNewOrder) {
            NewOrderView(viewModel: ordersViewModel)
        }
        .task {
            if let workshopId = sessionStore.workshop?.id {
                await ordersViewModel.loadOrders(workshopId: workshopId)
            }
        }
    }

    private var floatingButton: some View {
        Button {
            showNewOrder = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                Text("Nueva Orden")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(hex: "0D47A1"))
            .cornerRadius(28)
            .shadow(color: Color(hex: "0D47A1").opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private var welcomeHeader: some View {
        AxerCard {
            HStack {
                VStack(alignment: .leading, spacing: AxerSpacing.xxs) {
                    Text("Bienvenido")
                        .font(AxerTypography.caption1)
                        .foregroundColor(AxerColors.textSecondary)

                    Text(sessionStore.profile?.fullName ?? "Usuario")
                        .font(AxerTypography.title2)
                        .foregroundColor(AxerColors.textPrimary)

                    if let workshop = sessionStore.workshop {
                        Text(workshop.name)
                            .font(AxerTypography.subheadline)
                            .foregroundColor(AxerColors.primary)
                    }
                }
                Spacer()

                Circle()
                    .fill(AxerColors.primaryLight.opacity(0.2))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(initials)
                            .font(AxerTypography.headline)
                            .foregroundColor(AxerColors.primary)
                    )
            }
        }
    }

    private var quickStatsSection: some View {
        let stats = ordersViewModel.orderStats()

        return VStack(alignment: .leading, spacing: AxerSpacing.sm) {
            Text("Resumen")
                .font(AxerTypography.headline)
                .foregroundColor(AxerColors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AxerSpacing.sm) {
                StatCard(title: "Ordenes Hoy", value: "\(stats.today)", icon: "doc.text", color: AxerColors.primary)
                StatCard(title: "En Proceso", value: "\(stats.inProgress)", icon: "wrench", color: AxerColors.warning)
                StatCard(title: "Listas", value: "\(stats.ready)", icon: "checkmark.circle", color: AxerColors.success)
                StatCard(title: "Total", value: "\(stats.total)", icon: "tray.full", color: AxerColors.primaryDark)
            }
        }
    }

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: AxerSpacing.sm) {
            Text("Menu")
                .font(AxerTypography.headline)
                .foregroundColor(AxerColors.textPrimary)

            VStack(spacing: 0) {
                MenuRow(
                    icon: "doc.text",
                    title: "Ordenes",
                    subtitle: "Ver todas las ordenes"
                ) {
                    router.navigate(to: .orders)
                }

                Divider().padding(.leading, 56)

                MenuRow(
                    icon: "person.2",
                    title: "Equipo",
                    subtitle: "Administrar usuarios"
                ) {
                    router.navigate(to: .team)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
        }
    }

    private var recentOrdersSection: some View {
        VStack(alignment: .leading, spacing: AxerSpacing.sm) {
            HStack {
                Text("Ordenes Recientes")
                    .font(AxerTypography.headline)
                    .foregroundColor(AxerColors.textPrimary)

                Spacer()

                if !ordersViewModel.orders.isEmpty {
                    Button {
                        router.navigate(to: .orders)
                    } label: {
                        Text("Ver todas")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AxerColors.primary)
                    }
                }
            }

            if ordersViewModel.orders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "CBD5E1"))

                    Text("Sin ordenes aun")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "64748B"))

                    Text("Crea tu primera orden")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "94A3B8"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.white)
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    ForEach(ordersViewModel.activeOrders.prefix(3)) { order in
                        Button {
                            router.navigate(to: .orderDetail(order.id))
                        } label: {
                            OrderCard(order: order)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var initials: String {
        guard let name = sessionStore.profile?.fullName else { return "U" }
        let components = name.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }.map { String($0) }
        return initials.joined().uppercased()
    }
}

// MARK: - Menu Row
struct MenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(AxerColors.primary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AxerColors.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(AxerColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AxerColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        AxerCard {
            VStack(alignment: .leading, spacing: AxerSpacing.xs) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Spacer()
                }

                Text(value)
                    .font(AxerTypography.title1)
                    .foregroundColor(AxerColors.textPrimary)

                Text(title)
                    .font(AxerTypography.caption1)
                    .foregroundColor(AxerColors.textSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(SessionStore())
            .environmentObject(NetworkMonitor())
            .environmentObject(Router())
    }
}

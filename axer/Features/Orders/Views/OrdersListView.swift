import SwiftUI

struct OrdersListView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var viewModel = OrdersViewModel()
    @State private var showNewOrder = false
    @State private var selectedFilter: OrderStatus?

    var body: some View {
        ZStack {
            Color(hex: "F8FAFC")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Filter chips
                filterChips

                // Orders list
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.filteredOrders.isEmpty {
                    emptyState
                } else {
                    ordersList
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
        .navigationTitle("Ordenes")
        .sheet(isPresented: $showNewOrder) {
            NewOrderView(viewModel: viewModel)
        }
        .task {
            if let workshopId = sessionStore.workshop?.id {
                await viewModel.loadOrders(workshopId: workshopId)
            }
        }
        .refreshable {
            if let workshopId = sessionStore.workshop?.id {
                await viewModel.loadOrders(workshopId: workshopId)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(hex: "94A3B8"))

            TextField("Buscar orden, cliente, IMEI...", text: $viewModel.searchText)
                .font(.system(size: 16))

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(hex: "CBD5E1"))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "Todas",
                    count: viewModel.orders.count,
                    isSelected: selectedFilter == nil
                ) {
                    selectedFilter = nil
                }

                ForEach([OrderStatus.received, .diagnosing, .inRepair, .ready], id: \.self) { status in
                    FilterChip(
                        title: status.displayName,
                        count: viewModel.orders.filter { $0.status == status }.count,
                        color: Color(hex: status.color),
                        isSelected: selectedFilter == status
                    ) {
                        selectedFilter = selectedFilter == status ? nil : status
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Orders List

    private var ordersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredByStatus) { order in
                    NavigationLink(value: Route.orderDetail(order.id)) {
                        OrderCard(order: order)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    private var filteredByStatus: [Order] {
        if let filter = selectedFilter {
            return viewModel.filteredOrders.filter { $0.status == filter }
        }
        return viewModel.filteredOrders
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "CBD5E1"))

            Text(viewModel.searchText.isEmpty ? "No hay ordenes" : "Sin resultados")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "64748B"))

            Text(viewModel.searchText.isEmpty ? "Crea tu primera orden" : "Intenta con otro termino")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "94A3B8"))

            Spacer()
        }
    }

    // MARK: - Floating Button

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
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let count: Int
    var color: Color = Color(hex: "0D47A1")
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color(hex: "E2E8F0"))
                        .cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? .white : Color(hex: "64748B"))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color(hex: "E2E8F0"), lineWidth: 1)
            )
        }
    }
}

// MARK: - Order Card

struct OrderCard: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(order.orderNumber)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))

                Spacer()

                StatusBadge(status: order.status)
            }

            // Customer & Device
            HStack(spacing: 12) {
                // Customer
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "94A3B8"))

                    Text(order.customer?.name ?? "Cliente")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "64748B"))
                }

                Spacer()

                // Device
                HStack(spacing: 8) {
                    Image(systemName: order.deviceType.icon)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "94A3B8"))

                    Text([order.deviceBrand, order.deviceModel].compactMap { $0 }.joined(separator: " "))
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "64748B"))
                        .lineLimit(1)
                }
            }

            // Problem description
            Text(order.problemDescription)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "64748B"))
                .lineLimit(2)

            // Date
            if let date = order.receivedAt {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.system(size: 12))
                }
                .foregroundColor(Color(hex: "94A3B8"))
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: OrderStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10))
            Text(status.displayName)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(Color(hex: status.color))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(hex: status.color).opacity(0.15))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        OrdersListView()
            .environmentObject(SessionStore())
    }
}

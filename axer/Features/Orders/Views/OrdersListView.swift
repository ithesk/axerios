import SwiftUI

enum OwnershipFilter: String, CaseIterable {
    case all
    case mine

    var displayName: String {
        switch self {
        case .all: return L10n.Orders.all
        case .mine: return L10n.Orders.myOrders
        }
    }
}

struct OrdersListView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var viewModel = OrdersViewModel()
    @State private var showNewOrder = false
    @State private var selectedFilter: OrderStatus?
    @State private var ownershipFilter: OwnershipFilter = .mine

    // Scanner states
    @State private var showScanner = false
    @State private var isSearchingOrder = false
    @State private var scannedOrderId: UUID?
    @State private var showOrderNotFound = false

    var body: some View {
        ZStack {
            AxerColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Filter chips
                filterChips

                // Orders list
                if viewModel.isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        AxerLoadingSpinner()
                        Text(L10n.Orders.loading)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AxerColors.textSecondary)
                    }
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
        .navigationTitle(L10n.Orders.title)
        .sheet(isPresented: $showNewOrder) {
            NewOrderView(viewModel: viewModel)
        }
        .sheet(isPresented: $showScanner) {
            ScannerSheetView(
                scanMode: .qrCode,
                title: L10n.Orders.scanQr
            ) { code, _ in
                handleScannedCode(code)
            }
        }
        .navigationDestination(item: $scannedOrderId) { orderId in
            OrderDetailView(orderId: orderId)
        }
        .alert(L10n.Orders.title, isPresented: $showOrderNotFound) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(L10n.Orders.qrNotFound)
        }
        .task {
            if let workshopId = sessionStore.workshop?.id {
                await viewModel.loadOrders(workshopId: workshopId)
            }
        }
        .onChange(of: sessionStore.workshop?.id) { _, newWorkshopId in
            // Reload orders when workshop becomes available (after session restore)
            if let workshopId = newWorkshopId {
                Task {
                    await viewModel.loadOrders(workshopId: workshopId)
                }
            }
        }
        .refreshable {
            if let workshopId = sessionStore.workshop?.id {
                await viewModel.loadOrders(workshopId: workshopId, refresh: true)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AxerColors.textTertiary)

            TextField(L10n.Orders.searchHint, text: $viewModel.searchText)
                .font(.system(size: 16))

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AxerColors.textTertiary)
                }
            }

            // QR Scanner button
            Button {
                showScanner = true
            } label: {
                ZStack {
                    if isSearchingOrder {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 20))
                            .foregroundColor(AxerColors.primary)
                    }
                }
                .frame(width: 36, height: 36)
                .background(AxerColors.primaryLight)
                .cornerRadius(10)
            }
            .disabled(isSearchingOrder)
            .accessibilityLabel(L10n.Orders.scanQrAccessibility)
            .accessibilityHint(L10n.Orders.scanQrHint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AxerColors.surface)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        VStack(spacing: 8) {
            // Ownership filter row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(OwnershipFilter.allCases, id: \.self) { filter in
                        let count = filter == .mine ? myOrdersCount : viewModel.orders.count
                        OwnershipChip(
                            title: filter.displayName,
                            count: count,
                            isSelected: ownershipFilter == filter
                        ) {
                            ownershipFilter = filter
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // Status filter row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: L10n.Orders.allStatuses,
                        count: ordersForOwnershipFilter.count,
                        isSelected: selectedFilter == nil
                    ) {
                        selectedFilter = nil
                    }

                    ForEach([OrderStatus.received, .diagnosing, .inRepair, .ready], id: \.self) { status in
                        FilterChip(
                            title: status.displayName,
                            count: ordersForOwnershipFilter.filter { $0.status == status }.count,
                            color: Color(hex: status.color),
                            isSelected: selectedFilter == status
                        ) {
                            selectedFilter = selectedFilter == status ? nil : status
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private var myOrdersCount: Int {
        guard let userId = sessionStore.profile?.id else { return 0 }
        return viewModel.orders.filter { $0.ownerUserId == userId }.count
    }

    // MARK: - Scanner Handling

    private func handleScannedCode(_ code: String) {
        guard let workshopId = sessionStore.workshop?.id else { return }

        isSearchingOrder = true

        Task {
            if let order = await viewModel.findOrderByToken(code, workshopId: workshopId) {
                // Encontrada por token
                scannedOrderId = order.id
            } else if let order = await viewModel.findOrderByNumber(code, workshopId: workshopId) {
                // Encontrada por número de orden (fallback)
                scannedOrderId = order.id
            } else {
                // No encontrada
                showOrderNotFound = true
            }
            isSearchingOrder = false
        }
    }

    private var ordersForOwnershipFilter: [Order] {
        guard ownershipFilter == .mine, let userId = sessionStore.profile?.id else {
            return viewModel.filteredOrders
        }
        return viewModel.filteredOrders.filter { $0.ownerUserId == userId }
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
                    .onAppear {
                        // Load more when reaching last items
                        if order.id == filteredByStatus.last?.id {
                            loadMoreIfNeeded()
                        }
                    }
                }

                // Loading more indicator
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }

                // "No more orders" indicator
                if !viewModel.hasMorePages && !filteredByStatus.isEmpty {
                    Text(L10n.Orders.noMoreOrders)
                        .font(.system(size: 13))
                        .foregroundColor(AxerColors.textTertiary)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    private func loadMoreIfNeeded() {
        guard let workshopId = sessionStore.workshop?.id,
              viewModel.hasMorePages,
              !viewModel.isLoadingMore,
              viewModel.searchText.isEmpty else { return }

        Task {
            await viewModel.loadMoreOrders(workshopId: workshopId)
        }
    }

    private var filteredByStatus: [Order] {
        var orders = ordersForOwnershipFilter

        if let filter = selectedFilter {
            orders = orders.filter { $0.status == filter }
        }

        return orders
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(AxerColors.textTertiary)

            Text(viewModel.searchText.isEmpty ? L10n.Orders.noOrders : L10n.Orders.noResults)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AxerColors.textSecondary)

            Text(viewModel.searchText.isEmpty ? L10n.Orders.createFirst : L10n.Orders.tryAnother)
                .font(.system(size: 15))
                .foregroundColor(AxerColors.textTertiary)

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
                Text(L10n.Orders.newOrder)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(AxerColors.textInverse)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AxerColors.buttonPrimary)
            .cornerRadius(28)
            .shadow(color: AxerColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel(L10n.Orders.newOrder)
        .accessibilityHint("Crear una nueva orden de reparación")
    }
}

// MARK: - Ownership Chip

struct OwnershipChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if title == L10n.Orders.myOrders {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                }

                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? AxerColors.textInverse.opacity(0.25) : AxerColors.border)
                    .cornerRadius(6)
            }
            .foregroundColor(isSelected ? AxerColors.textInverse : AxerColors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? AxerColors.primary : AxerColors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : AxerColors.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let count: Int
    var color: Color = AxerColors.primary
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
                        .background(isSelected ? AxerColors.textInverse.opacity(0.3) : AxerColors.border)
                        .cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? AxerColors.textInverse : AxerColors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : AxerColors.surface)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : AxerColors.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Order Card

struct OrderCard: View {
    @EnvironmentObject var sessionStore: SessionStore
    let order: Order
    @State private var isPressed = false

    private var isMyOrder: Bool {
        order.ownerUserId == sessionStore.profile?.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Numero de orden (bold) + Estado (chip)
            HStack(alignment: .center) {
                Text(order.orderNumber)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(AxerColors.textPrimary)

                Spacer()

                StatusBadge(status: order.status)
            }

            // 2. Cliente + Modelo (info principal)
            HStack(spacing: 6) {
                Text(order.customer?.name ?? "Cliente")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AxerColors.textPrimary)

                Text("•")
                    .foregroundColor(AxerColors.textTertiary)

                Image(systemName: order.deviceType.icon)
                    .font(.system(size: 12))
                    .foregroundColor(AxerColors.textSecondary)

                Text(deviceDescription)
                    .font(.system(size: 14))
                    .foregroundColor(AxerColors.textSecondary)
                    .lineLimit(1)
            }

            // 3. Problema (texto secundario)
            Text(order.problemDescription)
                .font(.system(size: 13))
                .foregroundColor(AxerColors.textTertiary)
                .lineLimit(2)

            // 4. Owner chip + Fecha
            HStack {
                // Owner chip
                if isMyOrder {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                        Text(L10n.OrderDetail.mine)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(AxerColors.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AxerColors.successLight)
                    .cornerRadius(6)
                } else if let owner = order.owner {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                        Text(ownerShortName(owner))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(AxerColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AxerColors.surfaceSecondary)
                    .cornerRadius(6)
                }

                Spacer()

                // Fecha (muy sutil)
                if let date = order.receivedAt {
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.system(size: 11))
                        .foregroundColor(AxerColors.textTertiary)
                }
            }
        }
        .padding(16)
        .background(AxerColors.surface)
        .cornerRadius(12)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .combine)
        .accessibilityLabel(orderAccessibilityLabel)
        .accessibilityHint("Toca para ver detalles de la orden")
    }

    private var deviceDescription: String {
        [order.deviceBrand, order.deviceModel]
            .compactMap { $0 }
            .joined(separator: " ")
            .isEmpty ? order.deviceType.displayName : [order.deviceBrand, order.deviceModel].compactMap { $0 }.joined(separator: " ")
    }

    private var orderAccessibilityLabel: String {
        var parts: [String] = []
        parts.append("Orden \(order.orderNumber)")
        parts.append(order.status.displayName)
        if let customerName = order.customer?.name {
            parts.append("Cliente: \(customerName)")
        }
        parts.append("Dispositivo: \(deviceDescription)")
        parts.append(order.problemDescription)
        if isMyOrder {
            parts.append("Asignada a ti")
        } else if let owner = order.owner?.fullName {
            parts.append("Asignada a \(owner)")
        }
        return parts.joined(separator: ". ")
    }

    private func ownerShortName(_ owner: Profile) -> String {
        guard let name = owner.fullName else { return "?" }
        let components = name.split(separator: " ")
        if let firstName = components.first {
            return String(firstName)
        }
        return name
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: OrderStatus
    @State private var isPulsing = false

    private var isActiveStatus: Bool {
        [.received, .diagnosing, .inRepair].contains(status)
    }

    private var accessibilityDescription: String {
        switch status {
        case .received:
            return "Estado: Recibido. La orden está pendiente de diagnóstico."
        case .diagnosing:
            return "Estado: En diagnóstico. Se está evaluando el dispositivo."
        case .quoted:
            return "Estado: Cotizado. Se envió cotización al cliente."
        case .approved:
            return "Estado: Aprobado. El cliente aprobó la reparación."
        case .inRepair:
            return "Estado: En reparación. Se está trabajando en el dispositivo."
        case .ready:
            return "Estado: Listo. El dispositivo está listo para entregar."
        case .delivered:
            return "Estado: Entregado. El dispositivo fue entregado al cliente."
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                // Pulse circle for active statuses
                if isActiveStatus {
                    Circle()
                        .fill(Color(hex: status.color))
                        .frame(width: 6, height: 6)
                        .scaleEffect(isPulsing ? 1.8 : 1.0)
                        .opacity(isPulsing ? 0 : 0.6)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                }

                Image(systemName: status.icon)
                    .font(.system(size: 10))
            }

            Text(status.displayName)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(Color(hex: status.color))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(hex: status.color).opacity(0.12))
        .cornerRadius(12)
        .accessibilityLabel(accessibilityDescription)
        .onAppear {
            if isActiveStatus {
                isPulsing = true
            }
        }
    }
}

// MARK: - Loading Spinner

struct AxerLoadingSpinner: View {
    @State private var isAnimating = false
    var size: CGFloat = 32
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(AxerColors.primary.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AxerColors.primary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 1.0)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    NavigationStack {
        OrdersListView()
            .environmentObject(SessionStore())
    }
}

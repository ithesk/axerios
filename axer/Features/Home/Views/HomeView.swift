import SwiftUI
import PhotosUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var router: Router
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @StateObject private var ordersViewModel = OrdersViewModel()
    @State private var showNewOrder = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var currentStatsPage = 0

    var body: some View {
        ZStack {
            AxerColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                OfflineBanner()

                ScrollView {
                    if horizontalSizeClass == .regular {
                        // iPad: Horizontal dashboard layout
                        iPadDashboard
                    } else {
                        // iPhone: Vertical layout with carousel
                        iPhoneDashboard
                    }
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
        .navigationBarHidden(true)
        .sheet(isPresented: $showNewOrder) {
            NewOrderView(viewModel: ordersViewModel)
        }
        .task {
            if let workshopId = sessionStore.workshop?.id {
                await ordersViewModel.loadOrders(workshopId: workshopId)
                await ordersViewModel.loadQuotes(workshopId: workshopId)
            }
        }
        .onChange(of: sessionStore.workshop?.id) { _, newWorkshopId in
            // Reload orders when workshop becomes available (after session restore)
            if let workshopId = newWorkshopId {
                Task {
                    await ordersViewModel.loadOrders(workshopId: workshopId)
                    await ordersViewModel.loadQuotes(workshopId: workshopId)
                }
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
                Text(L10n.Home.newOrder)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(AxerColors.textInverse)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AxerColors.buttonPrimary)
            .cornerRadius(28)
            .shadow(color: AxerColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel(L10n.Home.newOrder)
        .accessibilityHint(L10n.Accessibility.newOrderHint)
    }

    // MARK: - iPad Dashboard Layout

    private var iPadDashboard: some View {
        VStack(spacing: 20) {
            welcomeHeader

            // Stats cards in horizontal row
            HStack(alignment: .top, spacing: 16) {
                activeOrdersCard
                todayQuotesCard
                monthSummaryCard
            }

            recentOrdersSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 80)
    }

    // MARK: - iPhone Dashboard Layout

    private var iPhoneDashboard: some View {
        VStack(spacing: 20) {
            welcomeHeader
            quickStatsSection
            recentOrdersSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 80)
    }

    private var welcomeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(L10n.Home.greeting(sessionStore.profile?.firstName ?? "Usuario"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AxerColors.textPrimary)
                    Text("👋")
                        .font(.system(size: 26))
                }

                if let workshop = sessionStore.workshop {
                    Text(workshop.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AxerColors.primary)
                }
            }
            Spacer()

            // Avatar con PhotosPicker
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    if let avatarUrl = sessionStore.profile?.avatarUrl,
                       let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure(_):
                                avatarPlaceholder
                            case .empty:
                                ProgressView()
                            @unknown default:
                                avatarPlaceholder
                            }
                        }
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                    } else {
                        avatarPlaceholder
                    }

                    // Overlay de carga
                    if isUploadingAvatar {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 52, height: 52)
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await handlePhotoSelection(newItem)
                }
            }
            .accessibilityLabel(L10n.Accessibility.profilePhoto)
            .accessibilityHint(L10n.Accessibility.profilePhotoHint)
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(AxerColors.primaryLight)
            .frame(width: 52, height: 52)
            .overlay(
                Text(initials)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AxerColors.primary)
            )
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item = item else {
            print("📷 [Avatar] No item selected")
            return
        }

        print("📷 [Avatar] Photo selected, starting upload...")
        isUploadingAvatar = true
        defer {
            isUploadingAvatar = false
            print("📷 [Avatar] Upload process finished")
        }

        do {
            print("📷 [Avatar] Loading transferable data...")
            guard let data = try await item.loadTransferable(type: Data.self) else {
                print("📷 [Avatar] ERROR: Could not load data from photo")
                return
            }
            print("📷 [Avatar] Data loaded: \(data.count) bytes")

            // Comprimir imagen
            guard let uiImage = UIImage(data: data) else {
                print("📷 [Avatar] ERROR: Could not create UIImage from data")
                return
            }
            print("📷 [Avatar] UIImage created: \(uiImage.size)")

            guard let compressedData = uiImage.jpegData(compressionQuality: 0.7) else {
                print("📷 [Avatar] ERROR: Could not compress image")
                return
            }
            print("📷 [Avatar] Compressed to: \(compressedData.count) bytes")

            print("📷 [Avatar] Calling sessionStore.uploadAvatar...")
            let url = try await sessionStore.uploadAvatar(imageData: compressedData)
            print("📷 [Avatar] SUCCESS! Avatar URL: \(url)")
        } catch {
            print("📷 [Avatar] ERROR uploading: \(error.localizedDescription)")
            print("📷 [Avatar] Full error: \(error)")
        }
    }

    private var quickStatsSection: some View {
        VStack(spacing: 12) {
            // Carousel
            TabView(selection: $currentStatsPage) {
                activeOrdersCard
                    .tag(0)
                todayQuotesCard
                    .tag(1)
                monthSummaryCard
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 180)

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(currentStatsPage == index ? AxerColors.primary : AxerColors.textTertiary)
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentStatsPage)
                }
            }
        }
    }

    // MARK: - Slide 1: Active Orders
    private var activeOrdersCard: some View {
        // Count each status from active orders (not delivered)
        // Order flow: received → diagnosing → quoted → approved → inRepair → ready → delivered
        let allOrders = ordersViewModel.orders
        let active = ordersViewModel.activeOrders

        let receivedCount = active.filter { $0.status == .received }.count
        let diagnosingCount = active.filter { $0.status == .diagnosing }.count
        let quotedCount = active.filter { $0.status == .quoted }.count
        let approvedCount = active.filter { $0.status == .approved }.count
        let inRepairCount = active.filter { $0.status == .inRepair }.count
        let readyCount = active.filter { $0.status == .ready }.count

        // Total is the sum of all active statuses
        let totalActive = receivedCount + diagnosingCount + quotedCount + approvedCount + inRepairCount + readyCount
        let total = max(totalActive, 1) // Avoid division by zero

        // Debug log
        let _ = print("📊 [HomeView] orders.count=\(allOrders.count), activeOrders.count=\(active.count), totalActive=\(totalActive)")
        let _ = print("📊 [HomeView] received=\(receivedCount), diagnosing=\(diagnosingCount), quoted=\(quotedCount), approved=\(approvedCount), inRepair=\(inRepairCount), ready=\(readyCount)")

        // Calculate percentages for segmented bar
        let receivedPct = Double(receivedCount) / Double(total)
        let diagnosingPct = Double(diagnosingCount) / Double(total)
        let quotedPct = Double(quotedCount) / Double(total)
        let approvedPct = Double(approvedCount) / Double(total)
        let inRepairPct = Double(inRepairCount) / Double(total)
        let readyPct = Double(readyCount) / Double(total)

        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    AnimatedNumber(
                        value: totalActive,
                        font: .system(size: 24, weight: .bold),
                        color: AxerColors.textPrimary
                    )
                    Text(L10n.Home.activeOrders)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AxerColors.textPrimary)
                }
                Spacer()
            }

            // Segmented progress bar (follows order flow)
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    // 1. Received (gray slate)
                    if receivedCount > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AxerColors.textSecondary)
                            .frame(width: max(geometry.size.width * receivedPct - 1, 0))
                    }
                    // 2. Diagnosing (amber)
                    if diagnosingCount > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AxerColors.statusDiagnosing)
                            .frame(width: max(geometry.size.width * diagnosingPct - 1, 0))
                    }
                    // 3. Quoted (violet) - waiting for customer
                    if quotedCount > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AxerColors.statusQuoted)
                            .frame(width: max(geometry.size.width * quotedPct - 1, 0))
                    }
                    // 4. Approved (blue) - ready to start repair
                    if approvedCount > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AxerColors.statusApproved)
                            .frame(width: max(geometry.size.width * approvedPct - 1, 0))
                    }
                    // 5. In Repair (orange)
                    if inRepairCount > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AxerColors.statusInRepair)
                            .frame(width: max(geometry.size.width * inRepairPct - 1, 0))
                    }
                    // 6. Ready (green) - ready for delivery
                    if readyCount > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AxerColors.success)
                            .frame(width: max(geometry.size.width * readyPct - 1, 0))
                    }
                    // Empty space if no orders
                    if totalActive == 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AxerColors.border)
                    }
                }
            }
            .frame(height: 10)

            // Legend with counts and percentages (scrollable for many states)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if receivedCount > 0 {
                        SegmentLabel(
                            color: AxerColors.textSecondary,
                            label: L10n.Status.received,
                            count: receivedCount,
                            percentage: Int(receivedPct * 100)
                        )
                    }
                    if diagnosingCount > 0 {
                        SegmentLabel(
                            color: AxerColors.statusDiagnosing,
                            label: L10n.Status.diagnosing,
                            count: diagnosingCount,
                            percentage: Int(diagnosingPct * 100)
                        )
                    }
                    if quotedCount > 0 {
                        SegmentLabel(
                            color: AxerColors.statusQuoted,
                            label: L10n.Status.quoted,
                            count: quotedCount,
                            percentage: Int(quotedPct * 100)
                        )
                    }
                    if approvedCount > 0 {
                        SegmentLabel(
                            color: AxerColors.statusApproved,
                            label: L10n.Status.approved,
                            count: approvedCount,
                            percentage: Int(approvedPct * 100)
                        )
                    }
                    if inRepairCount > 0 {
                        SegmentLabel(
                            color: AxerColors.statusInRepair,
                            label: L10n.Status.inRepair,
                            count: inRepairCount,
                            percentage: Int(inRepairPct * 100)
                        )
                    }
                    if readyCount > 0 {
                        SegmentLabel(
                            color: AxerColors.success,
                            label: L10n.Status.ready,
                            count: readyCount,
                            percentage: Int(readyPct * 100)
                        )
                    }
                }
            }

            // Ready for delivery message
            if readyCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AxerColors.success)
                        .font(.system(size: 14))
                    Text(L10n.Home.readyDelivery)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AxerColors.success)
                }
            } else {
                Text(L10n.Home.noneReady)
                    .font(.system(size: 13))
                    .foregroundColor(AxerColors.textTertiary)
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Accessibility.activeOrdersCard(totalActive, readyCount))
    }

    // MARK: - Slide 2: Today's Approved Quotes
    private var todayQuotesCard: some View {
        let todayAmount = ordersViewModel.todayApprovedAmount
        let todayCount = ordersViewModel.todayApprovedQuotes.count
        let currencySymbol = sessionStore.workshop?.displayCurrencySymbol ?? "$"

        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(AxerColors.success)
                    Text(L10n.Home.approvedToday)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AxerColors.textSecondary)
                }

                AnimatedNumber(
                    value: todayAmount,
                    format: .currency(symbol: currencySymbol),
                    font: .system(size: 32, weight: .bold),
                    color: AxerColors.textPrimary
                )

                Text(L10n.Home.quotesApproved)
                    .font(.system(size: 14))
                    .foregroundColor(AxerColors.textSecondary)

                Spacer()
            }

            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(AxerColors.successLight)
                    .frame(width: 52, height: 52)

                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AxerColors.success)
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Accessibility.todayQuotesCard(todayCount, "\(currencySymbol) \(todayAmount)"))
    }

    // MARK: - Slide 3: Month Summary
    private var monthSummaryCard: some View {
        let monthAmount = ordersViewModel.monthApprovedAmount
        let monthQuotes = ordersViewModel.monthApprovedQuotes.count
        let monthReceived = ordersViewModel.monthReceivedOrders.count
        let monthDelivered = ordersViewModel.monthDeliveredOrders.count
        let currencySymbol = sessionStore.workshop?.displayCurrencySymbol ?? "$"

        let monthName: String = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_ES")
            formatter.dateFormat = "MMMM"
            return formatter.string(from: Date()).capitalized
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(AxerColors.primary)
                    Text(L10n.Home.monthSummary(monthName))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AxerColors.textSecondary)
                }

                Spacer()

                AnimatedNumber(
                    value: monthAmount,
                    format: .currency(symbol: currencySymbol),
                    font: .system(size: 20, weight: .bold),
                    color: AxerColors.success
                )
            }

            Divider()

            HStack(spacing: 16) {
                MonthStatItem(icon: "tray.and.arrow.down.fill", label: "Recibidas", value: "\(monthReceived)", color: AxerColors.info)
                MonthStatItem(icon: "checkmark.seal.fill", label: "Aprobadas", value: "\(monthQuotes)", color: AxerColors.success)
                MonthStatItem(icon: "shippingbox.fill", label: "Entregadas", value: "\(monthDelivered)", color: AxerColors.statusQuoted)
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Accessibility.monthSummaryCard(monthName, monthReceived, monthQuotes, monthDelivered))
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }

    private var recentOrdersSection: some View {
        VStack(alignment: .leading, spacing: AxerSpacing.sm) {
            HStack {
                Text(L10n.Home.recentOrders)
                    .font(AxerTypography.headline)
                    .foregroundColor(AxerColors.textPrimary)

                Spacer()

                if !ordersViewModel.orders.isEmpty {
                    Button {
                        router.navigate(to: .orders)
                    } label: {
                        Text(L10n.Home.viewAll)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AxerColors.primary)
                    }
                }
            }

            if ordersViewModel.orders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 44))
                        .foregroundColor(AxerColors.textTertiary)

                    Text(L10n.Home.noOrdersYet)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AxerColors.textSecondary)

                    Text(L10n.Home.createFirst)
                        .font(.system(size: 13))
                        .foregroundColor(AxerColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(AxerColors.surface)
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

// MARK: - Month Stat Item

struct MonthStatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AxerColors.textPrimary)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AxerColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Segment Label

struct SegmentLabel: View {
    let color: Color
    let label: String
    let count: Int
    let percentage: Int

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text("\(count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AxerColors.textPrimary)

            Text("(\(percentage)%)")
                .font(.system(size: 11))
                .foregroundColor(AxerColors.textTertiary)
        }
    }
}

// MARK: - Status Chip

struct StatusChip: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AxerColors.textSecondary)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Animated Number

struct AnimatedNumber: View {
    let value: Double
    let duration: Double
    let format: NumberFormat
    let font: Font
    let color: Color

    @State private var displayValue: Double = 0

    enum NumberFormat {
        case integer
        case decimal(places: Int)
        case currency(symbol: String)
        case percentage
    }

    init(
        value: Double,
        duration: Double = 0.6,
        format: NumberFormat = .integer,
        font: Font = .system(size: 24, weight: .bold),
        color: Color = AxerColors.textPrimary
    ) {
        self.value = value
        self.duration = duration
        self.format = format
        self.font = font
        self.color = color
    }

    init(
        value: Decimal,
        duration: Double = 0.6,
        format: NumberFormat = .decimal(places: 2),
        font: Font = .system(size: 24, weight: .bold),
        color: Color = AxerColors.textPrimary
    ) {
        self.value = NSDecimalNumber(decimal: value).doubleValue
        self.duration = duration
        self.format = format
        self.font = font
        self.color = color
    }

    init(
        value: Int,
        duration: Double = 0.6,
        font: Font = .system(size: 24, weight: .bold),
        color: Color = AxerColors.textPrimary
    ) {
        self.value = Double(value)
        self.duration = duration
        self.format = .integer
        self.font = font
        self.color = color
    }

    var body: some View {
        Text(formattedValue)
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .onAppear {
                // Animate on first appear
                animateValue(to: value)
            }
            .onChange(of: value) { oldValue, newValue in
                // Re-animate when value changes
                if oldValue != newValue {
                    animateValue(to: newValue)
                }
            }
    }

    private var formattedValue: String {
        switch format {
        case .integer:
            return "\(Int(displayValue))"
        case .decimal(let places):
            return String(format: "%.\(places)f", displayValue)
        case .currency(let symbol):
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatter.groupingSeparator = ","
            let formatted = formatter.string(from: NSNumber(value: displayValue)) ?? "0.00"
            return "\(symbol) \(formatted)"
        case .percentage:
            return String(format: "%.0f%%", displayValue)
        }
    }

    private func animateValue(to targetValue: Double) {
        // If target is 0 or very small, just set it directly
        guard targetValue > 0.01 else {
            displayValue = targetValue
            return
        }

        let steps = 20
        let stepDuration = duration / Double(steps)
        let startValue = displayValue

        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                let progress = Double(step) / Double(steps)
                let easedProgress = 1 - pow(1 - progress, 3) // Cubic ease out
                displayValue = startValue + (targetValue - startValue) * easedProgress
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

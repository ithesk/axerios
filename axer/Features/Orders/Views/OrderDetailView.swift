import SwiftUI

struct OrderDetailView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var viewModel = OrdersViewModel()
    @StateObject private var quoteViewModel = QuoteViewModel()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    let orderId: UUID
    @State private var order: Order?
    @State private var isLoading = true
    @State private var showStatusPicker = false
    @State private var showShareSheet = false
    @State private var showAddNote = false
    @State private var showQuote = false
    @State private var activities: [OrderActivity] = []
    @State private var isLoadingActivity = false
    @State private var isGeneratingToken = false
    @State private var showPrintLabel = false
    @State private var showTechnicianPicker = false
    @State private var workshopUsers: [Profile] = []
    @State private var isTakingOrder = false
    @State private var showTakeOrderConfirm = false

    var body: some View {
        ZStack {
            AxerColors.background
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
            } else if let order = order {
                if horizontalSizeClass == .regular {
                    // iPad: 2 column layout
                    iPadLayout(order)
                } else {
                    // iPhone: single column layout
                    iPhoneLayout(order)
                }
            } else {
                Text(L10n.OrderDetail.notFound)
                    .foregroundColor(AxerColors.textSecondary)
            }
        }
        .navigationTitle(order?.orderNumber ?? L10n.Orders.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if order != nil {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(AxerColors.primary)
                    }
                    .accessibilityLabel(L10n.Accessibility.shareOrder)
                }
            }
        }
        .sheet(isPresented: $showStatusPicker) {
            if let order = order {
                StatusPickerView(currentStatus: order.status) { newStatus in
                    Task {
                        await updateStatus(newStatus)
                        await loadActivity()
                    }
                }
            }
        }
        .sheet(isPresented: $showAddNote) {
            AddNoteSheet { content in
                Task {
                    if await viewModel.addNote(orderId: orderId, content: content) != nil {
                        await loadActivity()
                    }
                }
            }
        }
        .sheet(isPresented: $showQuote, onDismiss: {
            Task {
                await quoteViewModel.loadQuote(orderId: orderId)
            }
        }) {
            if let order = order, let workshopId = sessionStore.workshop?.id {
                QuoteDetailView(
                    orderId: order.id,
                    workshopId: workshopId,
                    orderNumber: order.orderNumber
                )
            }
        }
        .sheet(isPresented: $showPrintLabel) {
            if let order = order {
                PrintLabelView(order: order)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let order = order {
                ShareOrderSheet(
                    order: order,
                    workshopName: sessionStore.workshop?.name
                )
            }
        }
        .task {
            await loadOrder()
            await loadActivity()
            await quoteViewModel.loadQuote(orderId: orderId)
        }
    }

    // MARK: - iPad Layout (2 columns)

    private func iPadLayout(_ order: Order) -> some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                // Left column: General info
                VStack(spacing: 16) {
                    headerCard(order)
                    statusTimelineCard(order)
                    customerCard(order)
                    ownerCard(order)
                    actionsSection(order)
                }
                .frame(maxWidth: .infinity)

                // Right column: Technical details
                VStack(spacing: 16) {
                    deviceCard(order)

                    if order.devicePowersOn != nil || order.deviceDiagnostics != nil {
                        diagnosticsCard(order)
                    }

                    problemCard(order)
                    quoteSection(order)
                    activitySection
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
    }

    // MARK: - iPhone Layout (single column)

    private func iPhoneLayout(_ order: Order) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard(order)
                statusTimelineCard(order)
                customerCard(order)
                ownerCard(order)
                deviceCard(order)

                if order.devicePowersOn != nil || order.deviceDiagnostics != nil {
                    diagnosticsCard(order)
                }

                problemCard(order)
                quoteSection(order)
                activitySection
                actionsSection(order)
            }
            .padding(16)
        }
    }

    // MARK: - Header Card

    private func headerCard(_ order: Order) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.orderNumber)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AxerColors.textPrimary)

                    if let date = order.receivedAt {
                        Text("\(L10n.Status.received) \(date.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 14))
                            .foregroundColor(AxerColors.textSecondary)
                    }
                }

                Spacer()

                Button {
                    showStatusPicker = true
                } label: {
                    StatusBadge(status: order.status)
                }
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Status Timeline Card

    private func statusTimelineCard(_ order: Order) -> some View {
        let allStatuses = OrderStatus.allCases
        let currentIndex = allStatuses.firstIndex(of: order.status) ?? 0

        return VStack(alignment: .leading, spacing: 16) {
            Text(L10n.OrderDetail.progress)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AxerColors.textSecondary)

            // Horizontal timeline
            HStack(spacing: 0) {
                ForEach(Array(allStatuses.enumerated()), id: \.element) { index, status in
                    let state = getTimelineState(index: index, currentIndex: currentIndex)

                    // Status node
                    VStack(spacing: 6) {
                        // Circle with icon
                        ZStack {
                            Circle()
                                .fill(state.backgroundColor)
                                .frame(width: 36, height: 36)

                            if state == .completed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: status.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(state.iconColor)
                            }
                        }

                        // Status name (only for current and adjacent)
                        if shouldShowLabel(index: index, currentIndex: currentIndex, total: allStatuses.count) {
                            Text(status.shortName)
                                .font(.system(size: 9, weight: state == .current ? .semibold : .regular))
                                .foregroundColor(state == .current ? Color(hex: status.color) : AxerColors.textTertiary)
                                .lineLimit(1)
                                .frame(width: 50)
                        } else {
                            Text("")
                                .font(.system(size: 9))
                                .frame(width: 50)
                        }
                    }

                    // Connector line (except for last item)
                    if index < allStatuses.count - 1 {
                        Rectangle()
                            .fill(index < currentIndex ? AxerColors.success : AxerColors.border)
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                            .offset(y: -12)
                    }
                }
            }

            // Current status detail
            HStack(spacing: 12) {
                Image(systemName: order.status.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: order.status.color))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.OrderDetail.currentStatus)
                        .font(.system(size: 12))
                        .foregroundColor(AxerColors.textSecondary)

                    Text(order.status.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: order.status.color))
                }

                Spacer()

                // Next status hint (if not delivered)
                if let nextStatus = getNextStatus(current: order.status) {
                    Button {
                        showStatusPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(L10n.OrderDetail.nextStatus)
                                .font(.system(size: 11))
                                .foregroundColor(AxerColors.textTertiary)
                            Text(nextStatus.shortName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AxerColors.primary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(AxerColors.primary)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(hex: order.status.color).opacity(0.08))
            .cornerRadius(10)
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    private enum TimelineState {
        case completed, current, pending

        var backgroundColor: Color {
            switch self {
            case .completed: return AxerColors.success
            case .current: return AxerColors.primary
            case .pending: return AxerColors.border
            }
        }

        var iconColor: Color {
            switch self {
            case .completed: return .white
            case .current: return .white
            case .pending: return AxerColors.textTertiary
            }
        }
    }

    private func getTimelineState(index: Int, currentIndex: Int) -> TimelineState {
        if index < currentIndex {
            return .completed
        } else if index == currentIndex {
            return .current
        } else {
            return .pending
        }
    }

    private func shouldShowLabel(index: Int, currentIndex: Int, total: Int) -> Bool {
        // Show label for: first, current, last, and adjacent to current
        if index == 0 || index == total - 1 { return true }
        if index == currentIndex { return true }
        if abs(index - currentIndex) == 1 { return true }
        return false
    }

    private func getNextStatus(current: OrderStatus) -> OrderStatus? {
        let allStatuses = OrderStatus.allCases
        guard let currentIndex = allStatuses.firstIndex(of: current),
              currentIndex < allStatuses.count - 1 else {
            return nil
        }
        return allStatuses[currentIndex + 1]
    }

    // MARK: - Customer Card

    private func customerCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.OrderDetail.client, systemImage: "person.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AxerColors.textSecondary)

            if let customer = order.customer {
                HStack(spacing: 12) {
                    Circle()
                        .fill(AxerColors.primaryLight)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(customer.initials)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AxerColors.primary)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(customer.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AxerColors.textPrimary)

                        if let phone = customer.phone {
                            Button {
                                if let url = URL(string: "tel:\(phone)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 12))
                                    Text(phone)
                                }
                                .font(.system(size: 14))
                                .foregroundColor(AxerColors.primary)
                            }
                            .accessibilityLabel(L10n.Accessibility.callCustomer)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Owner Card (Responsable)

    private func ownerCard(_ order: Order) -> some View {
        let currentUserId = sessionStore.profile?.id
        let isOwner = order.ownerUserId == currentUserId
        let isAdmin = sessionStore.profile?.role == .admin
        let canTakeOrder = !isOwner && order.ownerUserId != nil

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.OrderDetail.responsible, systemImage: "person.badge.key.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AxerColors.textSecondary)

                Spacer()

                // Badge "Mía" si soy el owner
                if isOwner {
                    Text(L10n.OrderDetail.mine)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AxerColors.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AxerColors.successLight)
                        .cornerRadius(8)
                }
            }

            HStack(spacing: 12) {
                // Avatar del owner
                if let owner = order.owner {
                    if let avatarUrl = owner.avatarUrl, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                ownerAvatarPlaceholder(owner)
                            }
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                    } else {
                        ownerAvatarPlaceholder(owner)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(owner.fullName ?? "Usuario")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AxerColors.textPrimary)

                        Text(owner.role.displayName)
                            .font(.system(size: 13))
                            .foregroundColor(AxerColors.textSecondary)
                    }
                } else {
                    // Sin owner asignado
                    Circle()
                        .fill(AxerColors.border)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "person.fill.questionmark")
                                .foregroundColor(AxerColors.textTertiary)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.OrderDetail.unassigned)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AxerColors.textSecondary)

                        Text(L10n.OrderDetail.takeOrderHint)
                            .font(.system(size: 13))
                            .foregroundColor(AxerColors.textTertiary)
                    }
                }

                Spacer()
            }

            // Botones de acción
            if canTakeOrder || order.ownerUserId == nil {
                HStack(spacing: 12) {
                    // Botón Tomar Orden
                    Button {
                        showTakeOrderConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            if isTakingOrder {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "hand.raised.fill")
                            }
                            Text(L10n.OrderDetail.takeOrder)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AxerColors.primary)
                        .cornerRadius(10)
                    }
                    .disabled(isTakingOrder)

                    // Botón Asignar (solo admin)
                    if isAdmin {
                        Button {
                            Task {
                                workshopUsers = await viewModel.loadWorkshopUsers(workshopId: sessionStore.workshop?.id ?? UUID())
                            }
                            showTechnicianPicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.badge.plus")
                                Text(L10n.OrderDetail.assign)
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AxerColors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AxerColors.primaryLight)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
        .alert(L10n.OrderDetail.takeOrder, isPresented: $showTakeOrderConfirm) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.OrderDetail.take) {
                Task {
                    isTakingOrder = true
                    let result = await viewModel.takeOrder(orderId: order.id)
                    if case .success = result {
                        await loadOrder()
                    }
                    isTakingOrder = false
                }
            }
        } message: {
            Text(L10n.OrderDetail.takeOrderConfirm)
        }
        .sheet(isPresented: $showTechnicianPicker) {
            TechnicianPickerSheet(
                users: workshopUsers,
                currentOwnerId: order.ownerUserId
            ) { selectedUser in
                Task {
                    let result = await viewModel.assignOrder(orderId: order.id, toUserId: selectedUser.id)
                    if case .success = result {
                        await loadOrder()
                    }
                }
            }
        }
    }

    private func ownerAvatarPlaceholder(_ owner: Profile) -> some View {
        Circle()
            .fill(AxerColors.primaryLight)
            .frame(width: 48, height: 48)
            .overlay(
                Text(ownerInitials(owner))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AxerColors.primary)
            )
    }

    private func ownerInitials(_ owner: Profile) -> String {
        guard let name = owner.fullName else { return "?" }
        let components = name.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }.map { String($0) }
        return initials.joined().uppercased()
    }

    // MARK: - Device Card

    private func deviceCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.OrderDetail.device, systemImage: order.deviceType.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AxerColors.textSecondary)

            VStack(spacing: 10) {
                if let brand = order.deviceBrand, let model = order.deviceModel {
                    DetailRow(label: "Equipo", value: "\(brand) \(model)")
                }
                DetailRow(label: "Tipo", value: order.deviceType.displayName)
                if let color = order.deviceColor, !color.isEmpty {
                    DetailRow(label: "Color", value: color)
                }
                if let imei = order.deviceImei, !imei.isEmpty {
                    DetailRow(label: "IMEI", value: imei)
                }
                if let password = order.devicePassword, !password.isEmpty {
                    DetailRow(label: "Clave", value: password, isPrivate: true)
                }
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Diagnostics Card

    private func diagnosticsCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.OrderDetail.initialDiagnosis, systemImage: "checklist")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AxerColors.textSecondary)

            // Power status
            if let powersOn = order.devicePowersOn {
                HStack(spacing: 12) {
                    Image(systemName: powersOn ? "power.circle.fill" : "power.circle")
                        .font(.system(size: 20))
                        .foregroundColor(powersOn ? AxerColors.success : AxerColors.error)

                    Text(powersOn ? "El equipo enciende" : "El equipo NO enciende")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AxerColors.textPrimary)

                    Spacer()
                }
                .padding(12)
                .background(powersOn ? AxerColors.success.opacity(0.1) : AxerColors.error.opacity(0.1))
                .cornerRadius(10)
            }

            // Diagnostic checks
            if let diagnostics = order.deviceDiagnostics {
                let checks = getDiagnosticChecks(diagnostics: diagnostics, deviceType: order.deviceType, powersOn: order.devicePowersOn)

                if !checks.isEmpty {
                    // Adaptive grid: more columns on iPad
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 150 : 140))
                    ], spacing: 8) {
                        ForEach(checks, id: \.field) { check in
                            DiagnosticDetailRow(
                                field: check.field,
                                status: check.status
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    private func getDiagnosticChecks(diagnostics: DeviceDiagnostics, deviceType: DeviceType, powersOn: Bool?) -> [(field: DiagnosticField, status: DiagnosticCheckStatus)] {
        var checks: [(DiagnosticField, DiagnosticCheckStatus)] = []

        // Get relevant fields for this device type
        let relevantFields = DeviceDiagnostics.relevantChecks(for: deviceType, powersOn: powersOn)

        for field in relevantFields {
            let status = getStatusForField(field, diagnostics: diagnostics)
            // Only include if it was actually tested (not the default notTested)
            if status != .notTested {
                checks.append((field, status))
            }
        }

        return checks
    }

    private func getStatusForField(_ field: DiagnosticField, diagnostics: DeviceDiagnostics) -> DiagnosticCheckStatus {
        switch field {
        case .screen: return diagnostics.screen
        case .touch: return diagnostics.touch
        case .charging: return diagnostics.charging
        case .battery: return diagnostics.battery
        case .buttons: return diagnostics.buttons
        case .faceId: return diagnostics.faceId
        case .touchId: return diagnostics.touchId
        case .frontCamera: return diagnostics.frontCamera
        case .rearCamera: return diagnostics.rearCamera
        case .microphone: return diagnostics.microphone
        case .speaker: return diagnostics.speaker
        case .wifi: return diagnostics.wifi
        case .bluetooth: return diagnostics.bluetooth
        case .cellular: return diagnostics.cellular
        case .visibleDamage: return diagnostics.visibleDamage
        case .waterDamage: return diagnostics.waterDamage
        case .keyboard: return diagnostics.keyboard
        case .trackpad: return diagnostics.trackpad
        case .ports: return diagnostics.ports
        case .bootable: return diagnostics.bootable
        case .pairing: return diagnostics.pairing
        case .heartSensor: return diagnostics.heartSensor
        case .powerStatus: return .notTested
        }
    }

    // MARK: - Problem Card

    private func problemCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.OrderDetail.reportedProblem, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AxerColors.textSecondary)

            Text(order.problemDescription)
                .font(.system(size: 15))
                .foregroundColor(AxerColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Quote Section

    private func quoteSection(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.OrderDetail.quote, systemImage: "doc.text")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AxerColors.textSecondary)

                Spacer()

                if let quote = quoteViewModel.quote {
                    HStack(spacing: 6) {
                        Image(systemName: quote.status.icon)
                        Text(quote.status.displayName)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: quote.status.color))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: quote.status.color).opacity(0.1))
                    .cornerRadius(12)
                }
            }

            if let quote = quoteViewModel.quote {
                // Show quote summary
                Button {
                    showQuote = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("\(quote.items?.count ?? 0) items")
                                    .font(.system(size: 14))
                                    .foregroundColor(AxerColors.textSecondary)

                                // Badge de preguntas pendientes
                                if quoteViewModel.pendingQuestionsCount > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "bubble.left.fill")
                                            .font(.system(size: 10))
                                        Text("\(quoteViewModel.pendingQuestionsCount)")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AxerColors.error)
                                    .cornerRadius(10)
                                }
                            }

                            Text(quoteViewModel.formatCurrency(quote.total))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AxerColors.primary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AxerColors.textTertiary)
                    }
                    .padding(16)
                    .background(AxerColors.background)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            } else {
                // No quote yet
                Button {
                    showQuote = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AxerColors.primary)
                        Text(L10n.OrderDetail.createQuote)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AxerColors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AxerColors.primaryLight)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Actividad", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AxerColors.textSecondary)

                Spacer()

                Button {
                    showAddNote = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(L10n.OrderDetail.note)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AxerColors.primary)
                }
            }

            if isLoadingActivity {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if activities.isEmpty {
                Text(L10n.OrderDetail.noActivity)
                    .font(.system(size: 14))
                    .foregroundColor(AxerColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(activities.prefix(5).enumerated()), id: \.element.id) { index, activity in
                        ActivityRow(activity: activity, isLast: index == min(4, activities.count - 1))
                    }
                }
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Actions Section

    private func actionsSection(_ order: Order) -> some View {
        VStack(spacing: 12) {
            // Quick status change
            if order.status != .delivered {
                Button {
                    showStatusPicker = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text(L10n.OrderDetail.changeStatus)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AxerColors.primary)
                    .cornerRadius(26)
                }
                .accessibilityLabel(L10n.Accessibility.changeStatus)
            }

            // Print label button
            Button {
                showPrintLabel = true
            } label: {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                    Text(L10n.OrderDetail.printLabel)
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AxerColors.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AxerColors.primaryLight)
                .cornerRadius(26)
            }
            .accessibilityLabel(L10n.Accessibility.printLabel)

            // Share tracking link
            if let token = order.publicToken {
                Button {
                    shareTrackingLink(token: token)
                } label: {
                    HStack {
                        Image(systemName: "link.circle.fill")
                        Text(L10n.OrderDetail.shareTracking)
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AxerColors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AxerColors.primaryLight)
                    .cornerRadius(26)
                }
            } else {
                // Generate tracking link
                Button {
                    Task {
                        await generateTrackingLink()
                    }
                } label: {
                    HStack {
                        if isGeneratingToken {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(AxerColors.primary)
                        } else {
                            Image(systemName: "link.badge.plus")
                        }
                        Text(L10n.OrderDetail.generateLink)
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AxerColors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AxerColors.primaryLight)
                    .cornerRadius(26)
                }
                .disabled(isGeneratingToken)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func loadOrder() async {
        isLoading = true

        guard let workshopId = sessionStore.workshop?.id else {
            isLoading = false
            return
        }

        do {
            let response: [Order] = try await SupabaseClient.shared.client
                .from("orders")
                .select("*, customer:customers(*), owner:profiles!owner_user_id(id, full_name, role, avatar_url)")
                .eq("id", value: orderId.uuidString)
                .eq("workshop_id", value: workshopId.uuidString)
                .execute()
                .value

            order = response.first
        } catch {
            print("Error loading order: \(error)")
        }

        isLoading = false
    }

    private func updateStatus(_ newStatus: OrderStatus) async {
        guard let _ = order else { return }

        if await viewModel.updateOrderStatus(orderId: orderId, newStatus: newStatus) {
            order?.status = newStatus
        }

        showStatusPicker = false
    }

    private func loadActivity() async {
        isLoadingActivity = true
        activities = await viewModel.loadActivityTimeline(orderId: orderId)
        isLoadingActivity = false
    }

    private func shareTrackingLink(token: String) {
        let link = "https://axer-tracking.vercel.app/\(token)"
        let message = "Sigue el estado de tu reparacion aqui: \(link)"

        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // Configure popover for iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(
                    x: rootVC.view.bounds.midX,
                    y: rootVC.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
        }
    }

    private func generateTrackingLink() async {
        isGeneratingToken = true

        if let token = await viewModel.generateTrackingToken(orderId: orderId) {
            // Reload order to get updated token
            await loadOrder()
            // Auto-share after generating
            shareTrackingLink(token: token)
        }

        isGeneratingToken = false
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    var isPrivate: Bool = false

    @State private var showValue = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AxerColors.textSecondary)

            Spacer()

            if isPrivate {
                HStack(spacing: 8) {
                    Text(showValue ? value : "••••••")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AxerColors.textPrimary)

                    Button {
                        showValue.toggle()
                    } label: {
                        Image(systemName: showValue ? "eye.slash" : "eye")
                            .font(.system(size: 14))
                            .foregroundColor(AxerColors.textTertiary)
                    }
                }
            } else {
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AxerColors.textPrimary)
            }
        }
    }
}

// MARK: - Status Picker View

struct StatusPickerView: View {
    @Environment(\.dismiss) var dismiss

    let currentStatus: OrderStatus
    let onSelect: (OrderStatus) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(OrderStatus.allCases, id: \.self) { status in
                    Button {
                        onSelect(status)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: status.icon)
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: status.color))
                                .frame(width: 32)

                            Text(status.displayName)
                                .font(.system(size: 16))
                                .foregroundColor(AxerColors.textPrimary)

                            Spacer()

                            if status == currentStatus {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AxerColors.primary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle(L10n.OrderDetail.changeStatus)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let activity: OrderActivity
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(iconColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    )

                if !isLast {
                    Rectangle()
                        .fill(AxerColors.border)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AxerColors.textPrimary)

                if let content = activity.noteContent, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 13))
                        .foregroundColor(AxerColors.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let authorName = activity.authorName {
                        Text(authorName)
                            .font(.system(size: 12))
                            .foregroundColor(AxerColors.textTertiary)
                    }

                    Text(activity.createdAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 12))
                        .foregroundColor(AxerColors.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var iconName: String {
        switch activity.type {
        case .statusChange:
            return activity.newStatus?.icon ?? "arrow.right"
        case .note:
            return "note.text"
        case .photo:
            return "camera"
        }
    }

    private var iconColor: Color {
        switch activity.type {
        case .statusChange:
            if let status = activity.newStatus {
                return Color(hex: status.color)
            }
            return AxerColors.textSecondary
        case .note:
            return AxerColors.statusQuoted
        case .photo:
            return AxerColors.info
        }
    }

    private var title: String {
        switch activity.type {
        case .statusChange:
            if let oldStatus = activity.oldStatus, let newStatus = activity.newStatus {
                return "\(oldStatus.displayName) → \(newStatus.displayName)"
            } else if let newStatus = activity.newStatus {
                return "Estado: \(newStatus.displayName)"
            }
            return "Cambio de estado"
        case .note:
            return activity.isInternalNote == true ? "Nota interna" : "Nota"
        case .photo:
            return "Foto agregada"
        }
    }
}

// MARK: - Add Note Sheet

struct AddNoteSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var noteContent = ""
    @FocusState private var isFocused: Bool

    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $noteContent)
                    .font(.system(size: 16))
                    .padding(12)
                    .background(AxerColors.background)
                    .cornerRadius(12)
                    .frame(minHeight: 120)
                    .focused($isFocused)

                Text(L10n.OrderDetail.internalNotesHint)
                    .font(.system(size: 13))
                    .foregroundColor(AxerColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(20)
            .navigationTitle(L10n.OrderDetail.newNote)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                    .foregroundColor(AxerColors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.save) {
                        onSave(noteContent)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AxerColors.primary)
                    .disabled(noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Diagnostic Detail Row

struct DiagnosticDetailRow: View {
    let field: DiagnosticField
    let status: DiagnosticCheckStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: status.color))

            Text(field.displayName)
                .font(.system(size: 13))
                .foregroundColor(AxerColors.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(hex: status.color).opacity(0.08))
        .cornerRadius(8)
    }
}

// MARK: - Technician Picker Sheet

struct TechnicianPickerSheet: View {
    @Environment(\.dismiss) var dismiss

    let users: [Profile]
    let currentOwnerId: UUID?
    let onSelect: (Profile) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(users) { user in
                    Button {
                        onSelect(user)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            // Avatar
                            if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    default:
                                        userAvatarPlaceholder(user)
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                userAvatarPlaceholder(user)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.fullName ?? "Usuario")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AxerColors.textPrimary)

                                Text(user.role.displayName)
                                    .font(.system(size: 13))
                                    .foregroundColor(AxerColors.textSecondary)
                            }

                            Spacer()

                            // Current owner indicator
                            if user.id == currentOwnerId {
                                Text(L10n.OrderDetail.current)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AxerColors.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AxerColors.primaryLight)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(L10n.OrderDetail.assignTo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                    .foregroundColor(AxerColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func userAvatarPlaceholder(_ user: Profile) -> some View {
        Circle()
            .fill(AxerColors.primaryLight)
            .frame(width: 40, height: 40)
            .overlay(
                Text(userInitials(user))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AxerColors.primary)
            )
    }

    private func userInitials(_ user: Profile) -> String {
        guard let name = user.fullName else { return "?" }
        let components = name.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }.map { String($0) }
        return initials.joined().uppercased()
    }
}

// MARK: - Share Order Sheet

struct ShareOrderSheet: View {
    @Environment(\.dismiss) var dismiss
    let order: Order
    let workshopName: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview del mensaje
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.OrderDetail.preview)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AxerColors.textSecondary)

                    Text(shareMessage)
                        .font(.system(size: 14))
                        .foregroundColor(AxerColors.textPrimary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AxerColors.background)
                        .cornerRadius(12)
                }
                .padding(20)

                Divider()

                // Opciones de compartir
                VStack(spacing: 12) {
                    // WhatsApp
                    ShareOptionButton(
                        icon: "message.fill",
                        title: L10n.OrderDetail.whatsapp,
                        subtitle: order.customer?.phone ?? "Seleccionar contacto",
                        color: AxerColors.whatsapp
                    ) {
                        if let phone = order.customer?.phone, !phone.isEmpty {
                            shareViaWhatsApp(phone: phone)
                        } else {
                            shareViaWhatsAppGeneral()
                        }
                    }

                    // Email
                    ShareOptionButton(
                        icon: "envelope.fill",
                        title: L10n.OrderDetail.email,
                        subtitle: order.customer?.email ?? "Abrir correo",
                        color: AxerColors.primary
                    ) {
                        if let email = order.customer?.email, !email.isEmpty {
                            shareViaEmail(email: email)
                        } else {
                            shareViaEmailGeneral()
                        }
                    }
                }
                .padding(20)

                Spacer()
            }
            .navigationTitle(L10n.OrderDetail.shareOrder)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.close) {
                        dismiss()
                    }
                    .foregroundColor(AxerColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Share Message

    private var shareMessage: String {
        var message = ""

        if let workshop = workshopName {
            message += "*\(workshop)*\n\n"
        }

        message += "Orden: *\(order.orderNumber)*\n"
        message += "Estado: \(order.status.displayName)\n\n"

        if let customer = order.customer {
            message += "Cliente: \(customer.name)\n"
        }

        if let brand = order.deviceBrand, let model = order.deviceModel {
            message += "Equipo: \(brand) \(model)\n"
        } else {
            message += "Equipo: \(order.deviceType.displayName)\n"
        }

        message += "Problema: \(order.problemDescription)\n"

        if let token = order.publicToken {
            message += "\nSeguimiento: https://axer-tracking.vercel.app/\(token)"
        }

        return message
    }

    private var shareMessagePlain: String {
        shareMessage
            .replacingOccurrences(of: "*", with: "")
    }

    // MARK: - Share Actions

    private func shareViaWhatsApp(phone: String) {
        let cleanPhone = phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")

        let encodedMessage = shareMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "whatsapp://send?phone=\(cleanPhone)&text=\(encodedMessage)") {
            UIApplication.shared.open(url)
        }
        dismiss()
    }

    private func shareViaWhatsAppGeneral() {
        let encodedMessage = shareMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "whatsapp://send?text=\(encodedMessage)") {
            UIApplication.shared.open(url)
        }
        dismiss()
    }

    private func shareViaEmail(email: String) {
        let subject = "Orden \(order.orderNumber) - \(order.status.displayName)"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = shareMessagePlain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
        dismiss()
    }

    private func shareViaEmailGeneral() {
        let subject = "Orden \(order.orderNumber) - \(order.status.displayName)"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = shareMessagePlain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
        dismiss()
    }
}

// MARK: - Share Option Button

struct ShareOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(color)
                    .cornerRadius(12)

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
                    .font(.system(size: 14))
                    .foregroundColor(AxerColors.textTertiary)
            }
            .padding(12)
            .background(AxerColors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AxerColors.border, lineWidth: 1)
            )
        }
    }
}

#Preview {
    NavigationStack {
        OrderDetailView(orderId: UUID())
            .environmentObject(SessionStore())
    }
}

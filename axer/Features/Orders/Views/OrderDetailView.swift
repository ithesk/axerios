import SwiftUI

struct OrderDetailView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var viewModel = OrdersViewModel()
    @StateObject private var quoteViewModel = QuoteViewModel()

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

    var body: some View {
        ZStack {
            Color(hex: "F8FAFC")
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
            } else if let order = order {
                ScrollView {
                    VStack(spacing: 16) {
                        // Header card
                        headerCard(order)

                        // Status Timeline
                        statusTimelineCard(order)

                        // Customer card
                        customerCard(order)

                        // Device card
                        deviceCard(order)

                        // Diagnostics card (if available)
                        if order.devicePowersOn != nil || order.deviceDiagnostics != nil {
                            diagnosticsCard(order)
                        }

                        // Problem card
                        problemCard(order)

                        // Quote section
                        quoteSection(order)

                        // Activity Timeline
                        activitySection

                        // Actions
                        actionsSection(order)
                    }
                    .padding(16)
                }
            } else {
                Text("Orden no encontrada")
                    .foregroundColor(Color(hex: "64748B"))
            }
        }
        .navigationTitle(order?.orderNumber ?? "Orden")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if order != nil {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Color(hex: "0D47A1"))
                    }
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
        .sheet(isPresented: $showQuote) {
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
        .task {
            await loadOrder()
            await loadActivity()
            await quoteViewModel.loadQuote(orderId: orderId)
        }
    }

    // MARK: - Header Card

    private func headerCard(_ order: Order) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.orderNumber)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "0D2137"))

                    if let date = order.receivedAt {
                        Text("Recibido \(date.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "64748B"))
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
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Status Timeline Card

    private func statusTimelineCard(_ order: Order) -> some View {
        let allStatuses = OrderStatus.allCases
        let currentIndex = allStatuses.firstIndex(of: order.status) ?? 0

        return VStack(alignment: .leading, spacing: 16) {
            Text("Progreso")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "64748B"))

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
                                .foregroundColor(state == .current ? Color(hex: status.color) : Color(hex: "94A3B8"))
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
                            .fill(index < currentIndex ? Color(hex: "22C55E") : Color(hex: "E2E8F0"))
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
                    Text("Estado actual")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "64748B"))

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
                            Text("Siguiente:")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "94A3B8"))
                            Text(nextStatus.shortName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "0D47A1"))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "0D47A1"))
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(hex: order.status.color).opacity(0.08))
            .cornerRadius(10)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
    }

    private enum TimelineState {
        case completed, current, pending

        var backgroundColor: Color {
            switch self {
            case .completed: return Color(hex: "22C55E")
            case .current: return Color(hex: "0D47A1")
            case .pending: return Color(hex: "E2E8F0")
            }
        }

        var iconColor: Color {
            switch self {
            case .completed: return .white
            case .current: return .white
            case .pending: return Color(hex: "94A3B8")
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
            Label("Cliente", systemImage: "person.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "64748B"))

            if let customer = order.customer {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: "E3F2FD"))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(customer.initials)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "0D47A1"))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(customer.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "0D2137"))

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
                                .foregroundColor(Color(hex: "0D47A1"))
                            }
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Device Card

    private func deviceCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Dispositivo", systemImage: order.deviceType.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "64748B"))

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
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Diagnostics Card

    private func diagnosticsCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Diagnóstico Inicial", systemImage: "checklist")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "64748B"))

            // Power status
            if let powersOn = order.devicePowersOn {
                HStack(spacing: 12) {
                    Image(systemName: powersOn ? "power.circle.fill" : "power.circle")
                        .font(.system(size: 20))
                        .foregroundColor(powersOn ? Color(hex: "22C55E") : Color(hex: "EF4444"))

                    Text(powersOn ? "El equipo enciende" : "El equipo NO enciende")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "0D2137"))

                    Spacer()
                }
                .padding(12)
                .background(powersOn ? Color(hex: "22C55E").opacity(0.1) : Color(hex: "EF4444").opacity(0.1))
                .cornerRadius(10)
            }

            // Diagnostic checks
            if let diagnostics = order.deviceDiagnostics {
                let checks = getDiagnosticChecks(diagnostics: diagnostics, deviceType: order.deviceType, powersOn: order.devicePowersOn)

                if !checks.isEmpty {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
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
        .background(Color.white)
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
            Label("Problema Reportado", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "64748B"))

            Text(order.problemDescription)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "0D2137"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Quote Section

    private func quoteSection(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Cotizacion", systemImage: "doc.text")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "64748B"))

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
                            Text("\(quote.items?.count ?? 0) items")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "64748B"))

                            Text(quoteViewModel.formatCurrency(quote.total))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: "0D47A1"))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "94A3B8"))
                    }
                    .padding(16)
                    .background(Color(hex: "F8FAFC"))
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
                            .foregroundColor(Color(hex: "0D47A1"))
                        Text("Crear Cotizacion")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "0D47A1"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "E3F2FD"))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Actividad", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "64748B"))

                Spacer()

                Button {
                    showAddNote = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Nota")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "0D47A1"))
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
                Text("Sin actividad registrada")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "94A3B8"))
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
        .background(Color.white)
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
                        Text("Cambiar Estado")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "0D47A1"))
                    .cornerRadius(26)
                }
            }

            // Print label button
            Button {
                showPrintLabel = true
            } label: {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Imprimir Label")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "0D47A1"))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "E3F2FD"))
                .cornerRadius(26)
            }

            // Share tracking link
            if let token = order.publicToken {
                Button {
                    shareTrackingLink(token: token)
                } label: {
                    HStack {
                        Image(systemName: "link.circle.fill")
                        Text("Compartir Seguimiento")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "0D47A1"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "E3F2FD"))
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
                                .tint(Color(hex: "0D47A1"))
                        } else {
                            Image(systemName: "link.badge.plus")
                        }
                        Text("Generar Link de Seguimiento")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "0D47A1"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "E3F2FD"))
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
                .select("*, customer:customers(*)")
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
                .foregroundColor(Color(hex: "64748B"))

            Spacer()

            if isPrivate {
                HStack(spacing: 8) {
                    Text(showValue ? value : "••••••")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "0D2137"))

                    Button {
                        showValue.toggle()
                    } label: {
                        Image(systemName: showValue ? "eye.slash" : "eye")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "94A3B8"))
                    }
                }
            } else {
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "0D2137"))
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
                                .foregroundColor(Color(hex: "0D2137"))

                            Spacer()

                            if status == currentStatus {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color(hex: "0D47A1"))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Cambiar Estado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
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
                        .fill(Color(hex: "E2E8F0"))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "0D2137"))

                if let content = activity.noteContent, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "64748B"))
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let authorName = activity.authorName {
                        Text(authorName)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "94A3B8"))
                    }

                    Text(activity.createdAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "94A3B8"))
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
            return Color(hex: "64748B")
        case .note:
            return Color(hex: "8B5CF6")
        case .photo:
            return Color(hex: "3B82F6")
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
                    .background(Color(hex: "F8FAFC"))
                    .cornerRadius(12)
                    .frame(minHeight: 120)
                    .focused($isFocused)

                Text("Las notas internas solo son visibles para el equipo del taller")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "94A3B8"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Nueva Nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "64748B"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        onSave(noteContent)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "0D47A1"))
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
                .foregroundColor(Color(hex: "0D2137"))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(hex: status.color).opacity(0.08))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        OrderDetailView(orderId: UUID())
            .environmentObject(SessionStore())
    }
}

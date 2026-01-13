import SwiftUI
import PhotosUI

struct NewOrderView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionStore: SessionStore
    @ObservedObject var viewModel: OrdersViewModel

    // Wizard state
    @State private var currentStep = 0
    @State private var isCreating = false

    // Step 1: Customer
    @State private var customerSearch = ""
    @State private var searchResults: [Customer] = []
    @State private var selectedCustomer: Customer?
    @State private var isSearching = false
    @State private var showNewCustomer = false

    // New customer fields
    @State private var newCustomerName = ""
    @State private var newCustomerPhone = ""
    @State private var newCustomerEmail = ""

    // Step 2: Device
    @State private var deviceType: DeviceType = .iphone
    @State private var deviceBrand = "Apple"
    @State private var deviceModel = ""
    @State private var deviceImei = ""
    @State private var devicePassword = ""

    // Smart Diagnostics
    @State private var devicePowersOn: Bool? = nil
    @State private var diagnostics = DeviceDiagnostics()

    // Autocomplete
    @StateObject private var modelStore = DeviceModelStore.shared
    @State private var showBrandPicker = false
    @State private var showModelPicker = false
    @State private var brandSearchText = ""
    @State private var modelSearchText = ""
    @State private var isAddingNewBrand = false
    @State private var isAddingNewModel = false
    @State private var newBrandName = ""
    @State private var newModelName = ""

    // Step 3: Problem & Photos
    @State private var problemDescription = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []

    // IMEI Scanner
    @State private var showImeiScanner = false
    @State private var showCamera = false

    private var steps: [String] {
        [L10n.NewOrder.customer, L10n.NewOrder.device, L10n.NewOrder.problem]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AxerColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress
                    progressIndicator

                    // Content
                    TabView(selection: $currentStep) {
                        customerStep.tag(0)
                        deviceStep.tag(1)
                        problemStep.tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentStep)

                    // Bottom buttons
                    bottomButtons
                }
            }
            .navigationTitle(L10n.NewOrder.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                    .foregroundColor(AxerColors.textSecondary)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(image: Binding(
                    get: { nil },
                    set: { if let img = $0 { photoImages.append(img) } }
                ))
            }
            .sheet(isPresented: $showImeiScanner) {
                IMEIScannerView(scannedIMEI: $deviceImei)
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Capsule()
                        .fill(index <= currentStep ? AxerColors.primary : AxerColors.border)
                        .frame(height: 4)
                }
            }

            HStack {
                ForEach(0..<3) { index in
                    Text(steps[index])
                        .font(.system(size: 12, weight: index == currentStep ? .semibold : .regular))
                        .foregroundColor(index == currentStep ? AxerColors.primary : AxerColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AxerColors.surface)
    }

    // MARK: - Step 1: Customer

    private var customerStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.NewOrder.selectCustomer)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AxerColors.textPrimary)

                // Search field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AxerColors.textTertiary)

                    TextField("Buscar por nombre o telefono", text: $customerSearch)
                        .font(.system(size: 16))
                        .onChange(of: customerSearch) { _, newValue in
                            Task { await searchCustomers(query: newValue) }
                        }

                    if isSearching {
                        ProgressView()
                    }
                }
                .padding(14)
                .background(AxerColors.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AxerColors.border, lineWidth: 1)
                )

                // Results or New Customer
                if let customer = selectedCustomer {
                    selectedCustomerCard(customer)
                } else if !searchResults.isEmpty {
                    customerResults
                } else if !customerSearch.isEmpty && !isSearching {
                    noResultsView
                }

                // New customer form
                if showNewCustomer {
                    newCustomerForm
                }
            }
            .padding(24)
        }
    }

    private func selectedCustomerCard(_ customer: Customer) -> some View {
        HStack {
            Circle()
                .fill(AxerColors.primaryLight)
                .frame(width: 48, height: 48)
                .overlay(
                    Text(customer.initials)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AxerColors.primary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(customer.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AxerColors.textPrimary)

                if let phone = customer.phone {
                    Text(phone)
                        .font(.system(size: 14))
                        .foregroundColor(AxerColors.textSecondary)
                }
            }

            Spacer()

            Button {
                selectedCustomer = nil
                customerSearch = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AxerColors.textTertiary)
            }
        }
        .padding(16)
        .background(AxerColors.primaryLight)
        .cornerRadius(12)
    }

    private var customerResults: some View {
        VStack(spacing: 0) {
            ForEach(searchResults) { customer in
                Button {
                    selectedCustomer = customer
                    showNewCustomer = false
                } label: {
                    HStack {
                        Circle()
                            .fill(AxerColors.surfaceSecondary)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(customer.initials)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AxerColors.textSecondary)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(customer.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AxerColors.textPrimary)

                            if let phone = customer.phone {
                                Text(phone)
                                    .font(.system(size: 13))
                                    .foregroundColor(AxerColors.textSecondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(AxerColors.textTertiary)
                    }
                    .padding(12)
                }

                if customer.id != searchResults.last?.id {
                    Divider()
                }
            }
        }
        .background(AxerColors.surface)
        .cornerRadius(12)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Text(L10n.NewOrder.customerNotFound)
                .font(.system(size: 15))
                .foregroundColor(AxerColors.textSecondary)

            Button {
                showNewCustomer = true
                newCustomerName = customerSearch
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(L10n.NewOrder.createCustomer)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AxerColors.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(12)
    }

    private var newCustomerForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.NewOrder.newCustomer)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AxerColors.textPrimary)

            AxerTextField(
                placeholder: "Nombre completo",
                text: $newCustomerName,
                icon: "person",
                autocapitalization: .words
            )

            AxerTextField(
                placeholder: "Telefono",
                text: $newCustomerPhone,
                icon: "phone",
                keyboardType: .phonePad
            )

            AxerTextField(
                placeholder: "Email (opcional)",
                text: $newCustomerEmail,
                icon: "envelope",
                keyboardType: .emailAddress,
                autocapitalization: .never
            )

            Button {
                Task { await createNewCustomer() }
            } label: {
                Text(L10n.NewOrder.createCustomerButton)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(!newCustomerName.isEmpty ? AxerColors.primary : AxerColors.textTertiary)
                    .cornerRadius(24)
            }
            .disabled(newCustomerName.isEmpty)
        }
        .padding(16)
        .background(AxerColors.surface)
        .cornerRadius(12)
    }

    // MARK: - Step 2: Device

    private var deviceStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.NewOrder.deviceData)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AxerColors.textPrimary)

                // Device type - Grid 3x2
                deviceTypeSelector

                // Brand & Model with autocomplete
                brandModelSection

                // Powers on question
                powersOnSection

                // Dynamic diagnostic checklist
                if devicePowersOn != nil {
                    diagnosticChecklist
                }

                // Additional info (collapsible)
                additionalInfoSection
            }
            .padding(24)
        }
    }

    // MARK: - Device Type Selector (Grid 3x2)

    private var deviceTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.NewOrder.deviceType)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AxerColors.textSecondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(DeviceType.allCases, id: \.self) { type in
                    DeviceTypeButton(
                        type: type,
                        isSelected: deviceType == type
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            deviceType = type
                            // Reset diagnostics when changing type
                            devicePowersOn = nil
                            diagnostics = DeviceDiagnostics()
                            // Reset brand and model based on type
                            if type == .iphone {
                                deviceBrand = "Apple"
                            } else {
                                deviceBrand = ""
                            }
                            deviceModel = ""
                        }
                    }
                }
            }
        }
    }

    // MARK: - Brand & Model with Autocomplete

    private var brandModelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Brand selector
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.NewOrder.brand)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AxerColors.textSecondary)

                Button {
                    if deviceType != .iphone {
                        showBrandPicker = true
                    }
                } label: {
                    HStack {
                        if deviceType == .iphone {
                            Image(systemName: "apple.logo")
                                .foregroundColor(AxerColors.textSecondary)
                        }
                        Text(deviceBrand.isEmpty ? "Seleccionar marca" : deviceBrand)
                            .font(.system(size: 16))
                            .foregroundColor(deviceBrand.isEmpty ? AxerColors.textTertiary : AxerColors.textPrimary)
                        Spacer()
                        if deviceType != .iphone {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(AxerColors.textTertiary)
                        }
                    }
                    .padding(14)
                    .background(deviceType == .iphone ? AxerColors.surfaceSecondary : AxerColors.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AxerColors.border, lineWidth: deviceType == .iphone ? 0 : 1)
                    )
                }
                .disabled(deviceType == .iphone)
            }

            // Model selector
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.NewOrder.model)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AxerColors.textSecondary)

                Button {
                    showModelPicker = true
                } label: {
                    HStack {
                        Text(deviceModel.isEmpty ? "Seleccionar modelo" : deviceModel)
                            .font(.system(size: 16))
                            .foregroundColor(deviceModel.isEmpty ? AxerColors.textTertiary : AxerColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(AxerColors.textTertiary)
                    }
                    .padding(14)
                    .background(AxerColors.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AxerColors.border, lineWidth: 1)
                    )
                }
                .disabled(deviceBrand.isEmpty && deviceType != .iphone)
            }
        }
        .sheet(isPresented: $showBrandPicker) {
            BrandPickerSheet(
                deviceType: deviceType,
                selectedBrand: $deviceBrand,
                modelStore: modelStore,
                onBrandSelected: {
                    deviceModel = "" // Reset model when brand changes
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet(
                deviceType: deviceType,
                brand: deviceBrand,
                selectedModel: $deviceModel,
                modelStore: modelStore
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Powers On Section

    private var powersOnSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.NewOrder.deviceStatus)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AxerColors.textPrimary)

            HStack(spacing: 12) {
                PowerStatusButton(
                    title: "Enciende",
                    icon: "power",
                    isSelected: devicePowersOn == true,
                    color: "22C55E"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        devicePowersOn = true
                        diagnostics.powerStatus = true
                    }
                }

                PowerStatusButton(
                    title: "No enciende",
                    icon: "power.circle",
                    isSelected: devicePowersOn == false,
                    color: "EF4444"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        devicePowersOn = false
                        diagnostics.powerStatus = false
                    }
                }
            }
        }
        .padding(16)
        .background(AxerColors.surface)
        .cornerRadius(12)
    }

    // MARK: - Diagnostic Checklist

    private var diagnosticChecklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.NewOrder.quickChecklist)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AxerColors.textPrimary)

                Spacer()

                Text(devicePowersOn == true ? "Equipo encendido" : "Equipo apagado")
                    .font(.system(size: 12))
                    .foregroundColor(AxerColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AxerColors.surfaceSecondary)
                    .cornerRadius(6)
            }

            let relevantFields = DeviceDiagnostics.relevantChecks(for: deviceType, powersOn: devicePowersOn)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(relevantFields, id: \.self) { field in
                    DiagnosticCheckRow(
                        field: field,
                        status: getStatus(for: field),
                        onStatusChange: { newStatus in
                            setStatus(newStatus, for: field)
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(AxerColors.surface)
        .cornerRadius(12)
    }

    private func getStatus(for field: DiagnosticField) -> DiagnosticCheckStatus {
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

    private func setStatus(_ status: DiagnosticCheckStatus, for field: DiagnosticField) {
        switch field {
        case .screen: diagnostics.screen = status
        case .touch: diagnostics.touch = status
        case .charging: diagnostics.charging = status
        case .battery: diagnostics.battery = status
        case .buttons: diagnostics.buttons = status
        case .faceId: diagnostics.faceId = status
        case .touchId: diagnostics.touchId = status
        case .frontCamera: diagnostics.frontCamera = status
        case .rearCamera: diagnostics.rearCamera = status
        case .microphone: diagnostics.microphone = status
        case .speaker: diagnostics.speaker = status
        case .wifi: diagnostics.wifi = status
        case .bluetooth: diagnostics.bluetooth = status
        case .cellular: diagnostics.cellular = status
        case .visibleDamage: diagnostics.visibleDamage = status
        case .waterDamage: diagnostics.waterDamage = status
        case .keyboard: diagnostics.keyboard = status
        case .trackpad: diagnostics.trackpad = status
        case .ports: diagnostics.ports = status
        case .bootable: diagnostics.bootable = status
        case .pairing: diagnostics.pairing = status
        case .heartSensor: diagnostics.heartSensor = status
        case .powerStatus: break
        }
    }

    // MARK: - Additional Info Section

    @State private var showAdditionalInfo = false

    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAdditionalInfo.toggle()
                }
            } label: {
                HStack {
                    Text(L10n.NewOrder.additionalInfo)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AxerColors.textSecondary)

                    Spacer()

                    Image(systemName: showAdditionalInfo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(AxerColors.textTertiary)
                }
            }

            if showAdditionalInfo {
                VStack(spacing: 12) {
                    // IMEI (only for mobile devices)
                    if deviceType.isMobile {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.NewOrder.imei)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AxerColors.textSecondary)

                            HStack(spacing: 12) {
                                TextField("15 digitos", text: $deviceImei)
                                    .keyboardType(.numberPad)
                                    .padding(14)
                                    .background(AxerColors.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AxerColors.border, lineWidth: 1)
                                    )

                                // Barcode scanner button
                                Button {
                                    showImeiScanner = true
                                } label: {
                                    Image(systemName: "barcode.viewfinder")
                                        .font(.system(size: 22))
                                        .foregroundColor(AxerColors.primary)
                                        .frame(width: 52, height: 52)
                                        .background(AxerColors.primaryLight)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }

                    // Password/Pattern
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.NewOrder.passwordPattern)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AxerColors.textSecondary)

                        TextField("PIN o patron de desbloqueo", text: $devicePassword)
                            .padding(14)
                            .background(AxerColors.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AxerColors.border, lineWidth: 1)
                            )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(AxerColors.background)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AxerColors.border, lineWidth: 1)
        )
    }

    // MARK: - Step 3: Problem

    private var problemStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.NewOrder.describeProblem)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AxerColors.textPrimary)

                // Problem description
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.NewOrder.problemPlaceholder)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AxerColors.textSecondary)

                    TextEditor(text: $problemDescription)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(AxerColors.surface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AxerColors.border, lineWidth: 1)
                        )
                }

                // Photos
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.NewOrder.photosOptional)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AxerColors.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Camera button
                            Button {
                                showCamera = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 24))
                                    Text(L10n.NewOrder.camera)
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(AxerColors.primary)
                                .frame(width: 80, height: 80)
                                .background(AxerColors.primaryLight)
                                .cornerRadius(12)
                            }

                            // Photo picker
                            PhotosPicker(
                                selection: $selectedPhotos,
                                maxSelectionCount: 5,
                                matching: .images
                            ) {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 24))
                                    Text(L10n.NewOrder.gallery)
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(AxerColors.textSecondary)
                                .frame(width: 80, height: 80)
                                .background(AxerColors.surfaceSecondary)
                                .cornerRadius(12)
                            }
                            .onChange(of: selectedPhotos) { _, items in
                                Task { await loadPhotos(from: items) }
                            }

                            // Selected photos
                            ForEach(photoImages.indices, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: photoImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))

                                    Button {
                                        photoImages.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.5)))
                                    }
                                    .offset(x: 6, y: -6)
                                }
                            }
                        }
                    }
                }

                // Summary
                if selectedCustomer != nil {
                    orderSummary
                }
            }
            .padding(24)
        }
    }

    private var orderSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.NewOrder.summary)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AxerColors.textPrimary)

            VStack(spacing: 8) {
                SummaryRow(label: "Cliente", value: selectedCustomer?.name ?? "")
                SummaryRow(label: "Dispositivo", value: "\(deviceBrand) \(deviceModel)")
                SummaryRow(label: "Tipo", value: deviceType.displayName)
                if let powersOn = devicePowersOn {
                    SummaryRow(
                        label: "Estado",
                        value: powersOn ? "Enciende" : "No enciende"
                    )
                }
                if diagnosticsCount > 0 {
                    SummaryRow(
                        label: "Diagnostico",
                        value: "\(diagnosticsFails) fallas de \(diagnosticsCount) verificados"
                    )
                }
                if !deviceImei.isEmpty {
                    SummaryRow(label: "IMEI", value: deviceImei)
                }
            }
            .padding(16)
            .background(AxerColors.surface)
            .cornerRadius(12)
        }
    }

    private var diagnosticsCount: Int {
        let fields = DeviceDiagnostics.relevantChecks(for: deviceType, powersOn: devicePowersOn)
        return fields.filter { getStatus(for: $0) != .notTested }.count
    }

    private var diagnosticsFails: Int {
        let fields = DeviceDiagnostics.relevantChecks(for: deviceType, powersOn: devicePowersOn)
        return fields.filter { getStatus(for: $0) == .fail }.count
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text(L10n.Common.back)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AxerColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AxerColors.surface)
                        .cornerRadius(26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 26)
                                .stroke(AxerColors.border, lineWidth: 1)
                        )
                }
            }

            Button {
                // Dismiss keyboard when changing steps
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                if currentStep < 2 {
                    withAnimation { currentStep += 1 }
                } else {
                    Task { await createOrder() }
                }
            } label: {
                HStack {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(currentStep == 2 ? "Crear Orden" : "Continuar")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canContinue ? AxerColors.primary : AxerColors.textTertiary)
                .cornerRadius(26)
            }
            .disabled(!canContinue || isCreating)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AxerColors.surface)
    }

    private var canContinue: Bool {
        switch currentStep {
        case 0: return selectedCustomer != nil
        case 1: return true // Device info is optional except type
        case 2: return !problemDescription.isEmpty
        default: return false
        }
    }

    // MARK: - Actions

    private func searchCustomers(query: String) async {
        guard !query.isEmpty, let workshopId = sessionStore.workshop?.id else {
            searchResults = []
            return
        }

        isSearching = true
        searchResults = await viewModel.searchCustomers(query: query, workshopId: workshopId)
        isSearching = false
    }

    private func createNewCustomer() async {
        print("🔵 [UI] Botón Crear Cliente presionado")
        print("🔵 [UI] sessionStore.workshop: \(String(describing: sessionStore.workshop))")

        guard let workshopId = sessionStore.workshop?.id else {
            print("🔴 [UI] ERROR: No hay workshop_id disponible!")
            return
        }

        print("🔵 [UI] workshopId obtenido: \(workshopId)")
        print("🔵 [UI] Llamando a viewModel.createCustomer...")

        if let customer = await viewModel.createCustomer(
            workshopId: workshopId,
            name: newCustomerName,
            phone: newCustomerPhone,
            email: newCustomerEmail
        ) {
            print("🟢 [UI] Cliente creado exitosamente: \(customer.name)")
            selectedCustomer = customer
            showNewCustomer = false
        } else {
            print("🔴 [UI] createCustomer retornó nil")
        }
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                photoImages.append(image)
            }
        }
        selectedPhotos = []
    }

    private func createOrder() async {
        guard let workshopId = sessionStore.workshop?.id,
              let customerId = selectedCustomer?.id else { return }

        isCreating = true

        if let _ = await viewModel.createOrder(
            workshopId: workshopId,
            customerId: customerId,
            deviceType: deviceType,
            deviceBrand: deviceBrand,
            deviceModel: deviceModel,
            deviceColor: nil,
            deviceImei: deviceImei,
            devicePassword: devicePassword,
            devicePowersOn: devicePowersOn,
            diagnostics: devicePowersOn != nil ? diagnostics : nil,
            problemDescription: problemDescription,
            photos: photoImages
        ) {
            dismiss()
        }

        isCreating = false
    }
}

// MARK: - Device Type Button

struct DeviceTypeButton: View {
    let type: DeviceType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 22))
                Text(type.displayName)
                    .font(.system(size: 11))
            }
            .foregroundColor(isSelected ? AxerColors.primary : AxerColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(isSelected ? AxerColors.primaryLight : AxerColors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AxerColors.primary : AxerColors.border, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

// MARK: - Summary Row

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AxerColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AxerColors.textPrimary)
        }
    }
}

// MARK: - Power Status Button

struct PowerStatusButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : AxerColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isSelected ? Color(hex: color) : AxerColors.surfaceSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : AxerColors.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Diagnostic Check Row

struct DiagnosticCheckRow: View {
    let field: DiagnosticField
    @State var status: DiagnosticCheckStatus
    let onStatusChange: (DiagnosticCheckStatus) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: field.icon)
                .font(.system(size: 14))
                .foregroundColor(AxerColors.textSecondary)
                .frame(width: 20)

            Text(field.displayName)
                .font(.system(size: 13))
                .foregroundColor(AxerColors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Quick toggle: tap cycles through states
            Button {
                let nextStatus: DiagnosticCheckStatus
                switch status {
                case .notTested: nextStatus = .ok
                case .ok: nextStatus = .fail
                case .fail: nextStatus = .notTested
                }
                status = nextStatus
                onStatusChange(nextStatus)
            } label: {
                Image(systemName: status.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: status.color))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AxerColors.background)
        .cornerRadius(8)
    }
}

// MARK: - Brand Picker Sheet

struct BrandPickerSheet: View {
    let deviceType: DeviceType
    @Binding var selectedBrand: String
    @ObservedObject var modelStore: DeviceModelStore
    var onBrandSelected: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isAddingNew = false
    @State private var newBrandName = ""

    private var brands: [String] {
        modelStore.getBrands(for: deviceType)
    }

    private var filteredBrands: [String] {
        if searchText.isEmpty {
            return brands
        }
        return brands.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AxerColors.textTertiary)
                    TextField("Buscar marca", text: $searchText)
                        .font(.system(size: 16))
                }
                .padding(12)
                .background(AxerColors.surfaceSecondary)
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Brand list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredBrands, id: \.self) { brand in
                            Button {
                                selectedBrand = brand
                                onBrandSelected()
                                dismiss()
                            } label: {
                                HStack {
                                    Text(brand)
                                        .font(.system(size: 16))
                                        .foregroundColor(AxerColors.textPrimary)
                                    Spacer()
                                    if selectedBrand == brand {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AxerColors.primary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            Divider().padding(.leading, 16)
                        }

                        // Add new option
                        if !searchText.isEmpty && !filteredBrands.contains(where: { $0.lowercased() == searchText.lowercased() }) {
                            Button {
                                newBrandName = searchText
                                isAddingNew = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(AxerColors.primary)
                                    Text(L10n.NewOrder.addBrand(searchText))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(AxerColors.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.NewOrder.selectBrand)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel) { dismiss() }
                        .foregroundColor(AxerColors.textSecondary)
                }
            }
            .alert(L10n.NewOrder.addBrandPrompt, isPresented: $isAddingNew) {
                TextField(L10n.NewOrder.brand, text: $newBrandName)
                Button(L10n.Common.cancel, role: .cancel) { }
                Button(L10n.Common.add) {
                    if !newBrandName.isEmpty {
                        modelStore.saveBrand(newBrandName, for: deviceType)
                        selectedBrand = newBrandName
                        onBrandSelected()
                        dismiss()
                    }
                }
            } message: {
                Text(L10n.NewOrder.brandWillSave)
            }
        }
    }
}

// MARK: - Model Picker Sheet

struct ModelPickerSheet: View {
    let deviceType: DeviceType
    let brand: String
    @Binding var selectedModel: String
    @ObservedObject var modelStore: DeviceModelStore

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isAddingNew = false
    @State private var newModelName = ""

    private var models: [String] {
        modelStore.getModels(for: deviceType, brand: brand)
    }

    private var filteredModels: [String] {
        if searchText.isEmpty {
            return models
        }
        return models.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AxerColors.textTertiary)
                    TextField("Buscar modelo", text: $searchText)
                        .font(.system(size: 16))
                }
                .padding(12)
                .background(AxerColors.surfaceSecondary)
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Model list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if filteredModels.isEmpty && searchText.isEmpty {
                            // No models yet
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 40))
                                    .foregroundColor(AxerColors.textTertiary)
                                Text(L10n.NewOrder.noModelsSaved)
                                    .font(.system(size: 15))
                                    .foregroundColor(AxerColors.textSecondary)
                                Text(L10n.NewOrder.typeToAdd)
                                    .font(.system(size: 13))
                                    .foregroundColor(AxerColors.textTertiary)
                            }
                            .padding(.vertical, 40)
                        } else {
                            ForEach(filteredModels, id: \.self) { model in
                                Button {
                                    selectedModel = model
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(model)
                                            .font(.system(size: 16))
                                            .foregroundColor(AxerColors.textPrimary)
                                        Spacer()
                                        if selectedModel == model {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(AxerColors.primary)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                                Divider().padding(.leading, 16)
                            }
                        }

                        // Add new option
                        if !searchText.isEmpty && !filteredModels.contains(where: { $0.lowercased() == searchText.lowercased() }) {
                            Button {
                                newModelName = searchText
                                isAddingNew = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(AxerColors.primary)
                                    Text(L10n.NewOrder.addBrand(searchText))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(AxerColors.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.NewOrder.selectModel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel) { dismiss() }
                        .foregroundColor(AxerColors.textSecondary)
                }
            }
            .alert(L10n.NewOrder.addModelPrompt, isPresented: $isAddingNew) {
                TextField(L10n.NewOrder.model, text: $newModelName)
                Button(L10n.Common.cancel, role: .cancel) { }
                Button(L10n.Common.add) {
                    if !newModelName.isEmpty {
                        modelStore.saveModel(newModelName, for: deviceType, brand: brand)
                        selectedModel = newModelName
                        dismiss()
                    }
                }
            } message: {
                Text(L10n.NewOrder.modelWillSave(brand))
            }
        }
    }
}

#Preview {
    NewOrderView(viewModel: OrdersViewModel())
        .environmentObject(SessionStore())
}

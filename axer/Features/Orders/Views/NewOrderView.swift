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
    @State private var deviceType: DeviceType = .phone
    @State private var deviceBrand = ""
    @State private var deviceModel = ""
    @State private var deviceColor = ""
    @State private var deviceImei = ""
    @State private var devicePassword = ""

    // Step 3: Problem & Photos
    @State private var problemDescription = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var showCamera = false

    private let steps = ["Cliente", "Dispositivo", "Problema"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F8FAFC")
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
            .navigationTitle("Nueva Orden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "64748B"))
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(image: Binding(
                    get: { nil },
                    set: { if let img = $0 { photoImages.append(img) } }
                ))
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Capsule()
                        .fill(index <= currentStep ? Color(hex: "0D47A1") : Color(hex: "E2E8F0"))
                        .frame(height: 4)
                }
            }

            HStack {
                ForEach(0..<3) { index in
                    Text(steps[index])
                        .font(.system(size: 12, weight: index == currentStep ? .semibold : .regular))
                        .foregroundColor(index == currentStep ? Color(hex: "0D47A1") : Color(hex: "94A3B8"))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white)
    }

    // MARK: - Step 1: Customer

    private var customerStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Selecciona el cliente")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))

                // Search field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(hex: "94A3B8"))

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
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
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
                .fill(Color(hex: "E3F2FD"))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(customer.initials)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "0D47A1"))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(customer.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "0D2137"))

                if let phone = customer.phone {
                    Text(phone)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "64748B"))
                }
            }

            Spacer()

            Button {
                selectedCustomer = nil
                customerSearch = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color(hex: "CBD5E1"))
            }
        }
        .padding(16)
        .background(Color(hex: "E3F2FD"))
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
                            .fill(Color(hex: "F1F5F9"))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(customer.initials)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "64748B"))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(customer.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "0D2137"))

                            if let phone = customer.phone {
                                Text(phone)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "64748B"))
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "CBD5E1"))
                    }
                    .padding(12)
                }

                if customer.id != searchResults.last?.id {
                    Divider()
                }
            }
        }
        .background(Color.white)
        .cornerRadius(12)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Text("No se encontro el cliente")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "64748B"))

            Button {
                showNewCustomer = true
                newCustomerName = customerSearch
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Crear nuevo cliente")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "0D47A1"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white)
        .cornerRadius(12)
    }

    private var newCustomerForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nuevo Cliente")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "0D2137"))

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
                Text("Crear Cliente")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(!newCustomerName.isEmpty ? Color(hex: "0D47A1") : Color(hex: "CBD5E1"))
                    .cornerRadius(24)
            }
            .disabled(newCustomerName.isEmpty)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }

    // MARK: - Step 2: Device

    private var deviceStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Datos del dispositivo")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))

                // Device type
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tipo de dispositivo")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "64748B"))

                    HStack(spacing: 10) {
                        ForEach(DeviceType.allCases, id: \.self) { type in
                            DeviceTypeButton(
                                type: type,
                                isSelected: deviceType == type
                            ) {
                                deviceType = type
                            }
                        }
                    }
                }

                // Brand & Model
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Marca")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "64748B"))

                        TextField("Ej: Samsung", text: $deviceBrand)
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Modelo")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "64748B"))

                        TextField("Ej: Galaxy S24", text: $deviceModel)
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
                            )
                    }
                }

                // Color
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color (opcional)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "64748B"))

                    TextField("Ej: Negro, Azul", text: $deviceColor)
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
                        )
                }

                // IMEI
                VStack(alignment: .leading, spacing: 8) {
                    Text("IMEI (opcional)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "64748B"))

                    TextField("15 digitos", text: $deviceImei)
                        .keyboardType(.numberPad)
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
                        )
                }

                // Password/Pattern
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contrasena/Patron (opcional)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "64748B"))

                    TextField("PIN o patron de desbloqueo", text: $devicePassword)
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
                        )
                }
            }
            .padding(24)
        }
    }

    // MARK: - Step 3: Problem

    private var problemStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Describe el problema")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))

                // Problem description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Que le pasa al equipo?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "64748B"))

                    TextEditor(text: $problemDescription)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
                        )
                }

                // Photos
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fotos del equipo (opcional)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "64748B"))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Camera button
                            Button {
                                showCamera = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 24))
                                    Text("Camara")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(Color(hex: "0D47A1"))
                                .frame(width: 80, height: 80)
                                .background(Color(hex: "E3F2FD"))
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
                                    Text("Galeria")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(Color(hex: "64748B"))
                                .frame(width: 80, height: 80)
                                .background(Color(hex: "F1F5F9"))
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
            Text("Resumen")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "0D2137"))

            VStack(spacing: 8) {
                SummaryRow(label: "Cliente", value: selectedCustomer?.name ?? "")
                SummaryRow(label: "Dispositivo", value: "\(deviceBrand) \(deviceModel)")
                SummaryRow(label: "Tipo", value: deviceType.displayName)
                if !deviceImei.isEmpty {
                    SummaryRow(label: "IMEI", value: deviceImei)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text("Atras")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "64748B"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white)
                        .cornerRadius(26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 26)
                                .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
                        )
                }
            }

            Button {
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
                .background(canContinue ? Color(hex: "0D47A1") : Color(hex: "CBD5E1"))
                .cornerRadius(26)
            }
            .disabled(!canContinue || isCreating)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white)
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
            deviceColor: deviceColor,
            deviceImei: deviceImei,
            devicePassword: devicePassword,
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
            .foregroundColor(isSelected ? Color(hex: "0D47A1") : Color(hex: "64748B"))
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(isSelected ? Color(hex: "E3F2FD") : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "0D47A1") : Color(hex: "E2E8F0"), lineWidth: isSelected ? 2 : 1)
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
                .foregroundColor(Color(hex: "64748B"))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "0D2137"))
        }
    }
}

#Preview {
    NewOrderView(viewModel: OrdersViewModel())
        .environmentObject(SessionStore())
}

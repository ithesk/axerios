import SwiftUI

struct ServiceManagementView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var serviceCatalog = ServiceCatalogStore()
    @State private var showAddService = false
    @State private var editingService: WorkshopService?
    @State private var searchText = ""

    var body: some View {
        ZStack {
            AxerColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                searchBar

                if serviceCatalog.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if filteredServices.isEmpty {
                    emptyState
                } else {
                    servicesList
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
        .navigationTitle(L10n.Services.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddService) {
            AddServiceSheet(
                serviceCatalog: serviceCatalog,
                workshopId: sessionStore.workshop?.id ?? UUID(),
                currencySymbol: sessionStore.workshop?.displayCurrencySymbol ?? "$"
            )
        }
        .sheet(item: $editingService) { service in
            EditServiceSheet(
                service: service,
                serviceCatalog: serviceCatalog,
                currencySymbol: sessionStore.workshop?.displayCurrencySymbol ?? "$"
            )
        }
        .task {
            if let workshopId = sessionStore.workshop?.id {
                await serviceCatalog.loadServices(workshopId: workshopId)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AxerColors.textTertiary)

            TextField(L10n.Services.searchPlaceholder, text: $searchText)
                .font(.system(size: 16))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AxerColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AxerColors.surface)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Services List

    private var servicesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredServices) { service in
                    ServiceCard(
                        service: service,
                        currencySymbol: sessionStore.workshop?.displayCurrencySymbol ?? "$"
                    ) {
                        editingService = service
                    } onDelete: {
                        Task {
                            await serviceCatalog.deleteService(serviceId: service.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 80)
        }
    }

    private var filteredServices: [WorkshopService] {
        if searchText.isEmpty {
            return serviceCatalog.services
        }
        return serviceCatalog.services.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 60))
                .foregroundColor(AxerColors.textTertiary)

            Text(searchText.isEmpty ? L10n.Services.emptyTitle : L10n.Common.search)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AxerColors.textSecondary)

            Text(searchText.isEmpty ? L10n.Services.emptySubtitle : L10n.Services.emptySearch)
                .font(.system(size: 15))
                .foregroundColor(AxerColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if searchText.isEmpty {
                Button {
                    showAddService = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(L10n.Services.add)
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AxerColors.primary)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    // MARK: - Floating Button

    private var floatingButton: some View {
        Button {
            showAddService = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(AxerColors.primary)
                .cornerRadius(28)
                .shadow(color: AxerColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Service Card

struct ServiceCard: View {
    let service: WorkshopService
    var currencySymbol: String = "$"
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: service.quoteItemType.icon)
                .font(.system(size: 18))
                .foregroundColor(AxerColors.primary)
                .frame(width: 40, height: 40)
                .background(AxerColors.primaryLight)
                .cornerRadius(10)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AxerColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(service.quoteItemType.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(AxerColors.textSecondary)

                    Text("•")
                        .foregroundColor(AxerColors.textTertiary)

                    Text(L10n.Services.usedCount.replacingOccurrences(of: "%d", with: "\(service.useCount)"))
                        .font(.system(size: 12))
                        .foregroundColor(AxerColors.textTertiary)
                }
            }

            Spacer()

            // Price
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(currencySymbol) \(NSDecimalNumber(decimal: service.defaultPrice).intValue)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AxerColors.primary)

                HStack(spacing: 12) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(AxerColors.textSecondary)
                    }

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(AxerColors.error)
                    }
                }
            }
        }
        .padding(16)
        .background(AxerColors.surface)
        .cornerRadius(12)
        .confirmationDialog(L10n.Services.deleteTitle, isPresented: $showDeleteConfirm) {
            Button(L10n.Common.delete, role: .destructive) {
                onDelete()
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Services.deleteConfirm)
        }
    }
}

// MARK: - Add Service Sheet

struct AddServiceSheet: View {
    @Environment(\.dismiss) var dismiss

    let serviceCatalog: ServiceCatalogStore
    let workshopId: UUID
    var currencySymbol: String = "$"

    @State private var name = ""
    @State private var itemType: QuoteItemType = .service
    @State private var defaultPrice = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Services.infoSection) {
                    TextField(L10n.Services.namePlaceholder, text: $name)

                    Picker(L10n.Services.type, selection: $itemType) {
                        ForEach(QuoteItemType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section(L10n.Services.defaultPrice) {
                    HStack {
                        Text(currencySymbol)
                            .foregroundColor(AxerColors.textSecondary)
                        TextField(L10n.Services.pricePlaceholder, text: $defaultPrice)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle(L10n.Services.newTitle)
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
                        Task {
                            await saveService()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AxerColors.primary)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Decimal(string: defaultPrice) != nil
    }

    private func saveService() async {
        guard let price = Decimal(string: defaultPrice) else { return }

        _ = await serviceCatalog.addService(
            workshopId: workshopId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            itemType: itemType,
            defaultPrice: price
        )
        dismiss()
    }
}

// MARK: - Edit Service Sheet

struct EditServiceSheet: View {
    @Environment(\.dismiss) var dismiss

    let service: WorkshopService
    let serviceCatalog: ServiceCatalogStore
    var currencySymbol: String = "$"

    @State private var name: String
    @State private var itemType: QuoteItemType
    @State private var defaultPrice: String
    @State private var isActive: Bool

    init(service: WorkshopService, serviceCatalog: ServiceCatalogStore, currencySymbol: String = "$") {
        self.service = service
        self.serviceCatalog = serviceCatalog
        self.currencySymbol = currencySymbol
        _name = State(initialValue: service.name)
        _itemType = State(initialValue: service.quoteItemType)
        _defaultPrice = State(initialValue: "\(NSDecimalNumber(decimal: service.defaultPrice))")
        _isActive = State(initialValue: service.isActive)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Services.infoSection) {
                    TextField(L10n.Services.namePlaceholder, text: $name)

                    Picker(L10n.Services.type, selection: $itemType) {
                        ForEach(QuoteItemType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section(L10n.Services.defaultPrice) {
                    HStack {
                        Text(currencySymbol)
                            .foregroundColor(AxerColors.textSecondary)
                        TextField(L10n.Services.pricePlaceholder, text: $defaultPrice)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Toggle(L10n.Services.active, isOn: $isActive)
                } footer: {
                    Text(L10n.Services.inactiveHint)
                }

                Section {
                    HStack {
                        Text(L10n.Services.timesUsed)
                            .foregroundColor(AxerColors.textSecondary)
                        Spacer()
                        Text("\(service.useCount)")
                            .foregroundColor(AxerColors.textPrimary)
                    }

                    if let lastUsed = service.lastUsedAt {
                        HStack {
                            Text(L10n.Services.lastUsed)
                                .foregroundColor(AxerColors.textSecondary)
                            Spacer()
                            Text(lastUsed.formatted(.relative(presentation: .named)))
                                .foregroundColor(AxerColors.textPrimary)
                        }
                    }
                }
            }
            .navigationTitle(L10n.Services.editTitle)
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
                        Task {
                            await updateService()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AxerColors.primary)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Decimal(string: defaultPrice) != nil
    }

    private func updateService() async {
        guard let price = Decimal(string: defaultPrice) else { return }

        _ = await serviceCatalog.updateService(
            serviceId: service.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            itemType: itemType,
            defaultPrice: price,
            isActive: isActive
        )
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ServiceManagementView()
            .environmentObject(SessionStore())
    }
}

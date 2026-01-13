import SwiftUI

struct QuoteDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var viewModel = QuoteViewModel()

    let orderId: UUID
    let workshopId: UUID
    let orderNumber: String
    var customerName: String = ""
    var customerPhone: String? = nil

    @State private var showAddItem = false
    @State private var editingItem: QuoteItem?
    @State private var showStatusPicker = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AxerColors.background
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.quote == nil {
                    ProgressView()
                } else if let quote = viewModel.quote {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Status header
                            statusHeader(quote)

                            // Items list
                            itemsSection

                            // Totals
                            totalsSection(quote)

                            // Actions (siempre visible excepto si ya fue aprobada/rechazada)
                            if quote.status != .approved && quote.status != .rejected {
                                actionsSection(quote)
                            }
                        }
                        .padding(16)
                    }
                } else {
                    // No quote yet - show create button
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(AxerColors.textTertiary)

                        Text(L10n.Quote.noQuote)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AxerColors.textSecondary)

                        Text(L10n.Quote.createHint)
                            .font(.system(size: 14))
                            .foregroundColor(AxerColors.textTertiary)

                        Button {
                            Task {
                                await viewModel.createQuote(orderId: orderId, workshopId: workshopId)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text(L10n.Quote.create)
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(AxerColors.primary)
                            .cornerRadius(25)
                        }
                    }
                }
            }
            .navigationTitle(L10n.Quote.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.close) {
                        dismiss()
                    }
                    .foregroundColor(AxerColors.textSecondary)
                }

                if viewModel.quote != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showAddItem = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundColor(AxerColors.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                if let quoteId = viewModel.quote?.id {
                    AddQuoteItemSheet(quoteId: quoteId, workshopId: workshopId, viewModel: viewModel)
                }
            }
            .sheet(item: $editingItem) { item in
                EditQuoteItemSheet(item: item, viewModel: viewModel)
            }
            .sheet(isPresented: $showStatusPicker) {
                if let quote = viewModel.quote {
                    QuoteStatusPicker(currentStatus: quote.status) { newStatus in
                        Task {
                            await viewModel.updateStatus(newStatus)
                        }
                    }
                }
            }
            .task {
                viewModel.setWorkshop(sessionStore.workshop)
                await viewModel.loadQuote(orderId: orderId)
            }
        }
    }

    // MARK: - Status Header

    private func statusHeader(_ quote: Quote) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(orderNumber)
                    .font(.system(size: 14))
                    .foregroundColor(AxerColors.textSecondary)

                Text(L10n.Quote.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AxerColors.textPrimary)
            }

            Spacer()

            Button {
                showStatusPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: quote.status.icon)
                    Text(quote.status.displayName)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: quote.status.color))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: quote.status.color).opacity(0.1))
                .cornerRadius(16)
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.Quote.items)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AxerColors.textSecondary)

                Spacer()

                Text(L10n.Quote.itemsCount(viewModel.items.count))
                    .font(.system(size: 13))
                    .foregroundColor(AxerColors.textTertiary)
            }

            if viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 32))
                        .foregroundColor(AxerColors.textTertiary)

                    Text(L10n.Quote.addItemsHint)
                        .font(.system(size: 14))
                        .foregroundColor(AxerColors.textTertiary)

                    Button {
                        showAddItem = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text(L10n.Quote.addItem)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AxerColors.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.items) { item in
                        QuoteItemRow(item: item, viewModel: viewModel) {
                            editingItem = item
                        }

                        if item.id != viewModel.items.last?.id {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Totals Section

    private func totalsSection(_ quote: Quote) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(L10n.Quote.subtotal)
                    .font(.system(size: 14))
                    .foregroundColor(AxerColors.textSecondary)
                Spacer()
                Text(viewModel.formatCurrency(quote.subtotal))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AxerColors.textPrimary)
            }

            if quote.discountAmount > 0 {
                HStack {
                    Text(L10n.Quote.discount)
                        .font(.system(size: 14))
                        .foregroundColor(AxerColors.textSecondary)
                    Spacer()
                    Text("-\(viewModel.formatCurrency(quote.discountAmount))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AxerColors.success)
                }
            }

            if quote.taxRate > 0 {
                HStack {
                    Text("\(viewModel.taxName) (\(NSDecimalNumber(decimal: quote.taxRate).intValue)%)")
                        .font(.system(size: 14))
                        .foregroundColor(AxerColors.textSecondary)
                    Spacer()
                    Text(viewModel.formatCurrency(quote.taxAmount))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AxerColors.textPrimary)
                }
            }

            Divider()

            HStack {
                Text(L10n.Quote.total)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AxerColors.textPrimary)
                Spacer()
                Text(viewModel.formatCurrency(quote.total))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AxerColors.primary)
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Actions Section

    private func actionsSection(_ quote: Quote) -> some View {
        VStack(spacing: 12) {
            if !viewModel.items.isEmpty {
                // Boton principal: Compartir por WhatsApp
                Button {
                    shareViaWhatsApp()
                } label: {
                    HStack {
                        Image(systemName: quote.status == .draft ? "square.and.arrow.up" : "arrow.triangle.2.circlepath")
                        Text(quote.status == .draft ? L10n.Quote.create : L10n.Quote.create)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AxerColors.whatsapp)  // WhatsApp green
                    .cornerRadius(26)
                }

                // Boton secundario: Copiar link
                if let token = quote.publicToken, !token.isEmpty {
                    Button {
                        copyLinkToClipboard()
                    } label: {
                        HStack {
                            Image(systemName: "link")
                            Text(L10n.Quote.copyLink)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AxerColors.textSecondary)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Share Actions

    private func shareViaWhatsApp() {
        Task {
            // Primero marcar como enviado
            _ = await viewModel.updateStatus(.sent)

            // Generar mensaje
            let message = viewModel.generateShareMessage(
                orderNumber: orderNumber,
                customerName: customerName.isEmpty ? "Cliente" : customerName
            )

            // Abrir WhatsApp
            if let url = viewModel.shareViaWhatsApp(customerPhone: customerPhone, message: message) {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private func copyLinkToClipboard() {
        if let url = viewModel.quote?.publicURL {
            UIPasteboard.general.string = url
            // TODO: Mostrar toast de confirmacion
        }
    }
}

// MARK: - Quote Item Row

struct QuoteItemRow: View {
    let item: QuoteItem
    let viewModel: QuoteViewModel
    let onEdit: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.itemType.icon)
                .font(.system(size: 16))
                .foregroundColor(AxerColors.primary)
                .frame(width: 32, height: 32)
                .background(AxerColors.primaryLight)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AxerColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text("\(NSDecimalNumber(decimal: item.quantity).intValue) x \(viewModel.formatCurrency(item.unitPrice))")
                        .font(.system(size: 12))
                        .foregroundColor(AxerColors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(viewModel.formatCurrency(item.totalPrice))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AxerColors.textPrimary)

                HStack(spacing: 12) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(AxerColors.textSecondary)
                    }

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(AxerColors.error)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .confirmationDialog(L10n.Common.delete, isPresented: $showDeleteConfirm) {
            Button(L10n.Common.delete, role: .destructive) {
                Task {
                    await viewModel.deleteItem(itemId: item.id)
                }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        }
    }
}

// MARK: - Add Quote Item Sheet

struct AddQuoteItemSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var serviceCatalog = ServiceCatalogStore()

    let quoteId: UUID
    let workshopId: UUID
    let viewModel: QuoteViewModel

    @State private var description = ""
    @State private var itemType: QuoteItemType = .service
    @State private var quantity = "1"
    @State private var unitPrice = ""
    @State private var selectedServiceId: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Servicios sugeridos (catálogo + historial)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(L10n.Quote.frequentServices)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AxerColors.textSecondary)

                            if serviceCatalog.isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(serviceCatalog.suggestedServices) { service in
                                    QuickServiceChip(
                                        name: service.name,
                                        price: "\(viewModel.currencySymbol) \(NSDecimalNumber(decimal: service.defaultPrice).intValue)",
                                        isSelected: selectedServiceId == service.id,
                                        source: service.source
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedServiceId = service.id
                                            description = service.name
                                            unitPrice = "\(NSDecimalNumber(decimal: service.defaultPrice).intValue)"
                                            itemType = service.quoteItemType
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // Tipo
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.Quote.type)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AxerColors.textSecondary)

                        Picker(L10n.Quote.type, selection: $itemType) {
                            ForEach(QuoteItemType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 16)

                    // Descripción
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.Quote.description)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AxerColors.textSecondary)

                        TextField(L10n.Quote.description, text: $description, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(12)
                            .background(AxerColors.background)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 16)

                    // Precio
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.Quote.price)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AxerColors.textSecondary)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.Quote.quantity)
                                    .font(.system(size: 11))
                                    .foregroundColor(AxerColors.textTertiary)
                                TextField("1", text: $quantity)
                                    .keyboardType(.decimalPad)
                                    .padding(12)
                                    .background(AxerColors.background)
                                    .cornerRadius(10)
                            }
                            .frame(width: 80)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.Quote.unitPrice)
                                    .font(.system(size: 11))
                                    .foregroundColor(AxerColors.textTertiary)
                                HStack {
                                    Text(viewModel.currencySymbol)
                                        .foregroundColor(AxerColors.textTertiary)
                                    TextField("0", text: $unitPrice)
                                        .keyboardType(.decimalPad)
                                }
                                .padding(12)
                                .background(AxerColors.background)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Total
                    if let total = calculatedTotal {
                        HStack {
                            Text(L10n.Quote.total)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AxerColors.textPrimary)
                            Spacer()
                            Text(viewModel.formatCurrency(total))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AxerColors.primary)
                        }
                        .padding(16)
                        .background(AxerColors.primaryLight)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 20)
            }
            .background(AxerColors.surface)
            .navigationTitle(L10n.Quote.addItem)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                    .foregroundColor(AxerColors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.add) {
                        Task {
                            await addItem()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AxerColors.primary)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.large])
        .task {
            await serviceCatalog.loadSuggestedServices(workshopId: workshopId)
        }
    }

    private var calculatedTotal: Decimal? {
        guard let qty = Decimal(string: quantity),
              let price = Decimal(string: unitPrice) else {
            return nil
        }
        return qty * price
    }

    private var isValid: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Decimal(string: quantity) != nil &&
        Decimal(string: unitPrice) != nil
    }

    private func addItem() async {
        guard let qty = Decimal(string: quantity),
              let price = Decimal(string: unitPrice) else {
            return
        }

        if await viewModel.addItem(
            quoteId: quoteId,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            itemType: itemType,
            quantity: qty,
            unitPrice: price
        ) != nil {
            dismiss()
        }
    }
}

// MARK: - Edit Quote Item Sheet

struct EditQuoteItemSheet: View {
    @Environment(\.dismiss) var dismiss

    let item: QuoteItem
    let viewModel: QuoteViewModel

    @State private var description: String
    @State private var quantity: String
    @State private var unitPrice: String

    init(item: QuoteItem, viewModel: QuoteViewModel) {
        self.item = item
        self.viewModel = viewModel
        _description = State(initialValue: item.description)
        _quantity = State(initialValue: "\(NSDecimalNumber(decimal: item.quantity))")
        _unitPrice = State(initialValue: "\(NSDecimalNumber(decimal: item.unitPrice))")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Quote.description) {
                    TextField(L10n.Quote.description, text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(L10n.Quote.price) {
                    HStack {
                        Text(L10n.Quote.quantity)
                        Spacer()
                        TextField("1", text: $quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Text(L10n.Quote.unitPrice)
                        Spacer()
                        Text(viewModel.currencySymbol)
                            .foregroundColor(AxerColors.textSecondary)
                        TextField("0.00", text: $unitPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                if let total = calculatedTotal {
                    Section {
                        HStack {
                            Text(L10n.Quote.total)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(viewModel.formatCurrency(total))
                                .fontWeight(.bold)
                                .foregroundColor(AxerColors.primary)
                        }
                    }
                }
            }
            .navigationTitle(L10n.Quote.editItem)
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
                            await updateItem()
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

    private var calculatedTotal: Decimal? {
        guard let qty = Decimal(string: quantity),
              let price = Decimal(string: unitPrice) else {
            return nil
        }
        return qty * price
    }

    private var isValid: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Decimal(string: quantity) != nil &&
        Decimal(string: unitPrice) != nil
    }

    private func updateItem() async {
        guard let qty = Decimal(string: quantity),
              let price = Decimal(string: unitPrice) else {
            return
        }

        if await viewModel.updateItem(
            itemId: item.id,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: qty,
            unitPrice: price
        ) {
            dismiss()
        }
    }
}

// MARK: - Quote Status Picker

struct QuoteStatusPicker: View {
    @Environment(\.dismiss) var dismiss

    let currentStatus: QuoteStatus
    let onSelect: (QuoteStatus) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(QuoteStatus.allCases, id: \.self) { status in
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
            .navigationTitle(L10n.Quote.status)
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

// MARK: - Quick Service Chip

struct QuickServiceChip: View {
    let name: String
    let price: String
    let isSelected: Bool
    var source: String = "default"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? .white : AxerColors.textPrimary)
                        .lineLimit(1)

                    // Indicador de origen
                    if source == "history" {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : AxerColors.textTertiary)
                    } else if source == "catalog" {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : AxerColors.warning)
                    }
                }

                Text(price)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : AxerColors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? AxerColors.primary : AxerColors.surfaceSecondary)
            .cornerRadius(10)
        }
    }
}

#Preview {
    QuoteDetailView(
        orderId: UUID(),
        workshopId: UUID(),
        orderNumber: "ORD-0001"
    )
}

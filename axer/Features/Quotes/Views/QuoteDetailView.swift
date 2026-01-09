import SwiftUI

struct QuoteDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = QuoteViewModel()

    let orderId: UUID
    let workshopId: UUID
    let orderNumber: String

    @State private var showAddItem = false
    @State private var editingItem: QuoteItem?
    @State private var showStatusPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F8FAFC")
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

                            // Actions
                            if quote.status == .draft {
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
                            .foregroundColor(Color(hex: "CBD5E1"))

                        Text("Sin cotizacion")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "64748B"))

                        Text("Crea una cotizacion para esta orden")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "94A3B8"))

                        Button {
                            Task {
                                await viewModel.createQuote(orderId: orderId, workshopId: workshopId)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Crear Cotizacion")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color(hex: "0D47A1"))
                            .cornerRadius(25)
                        }
                    }
                }
            }
            .navigationTitle("Cotizacion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "64748B"))
                }

                if viewModel.quote != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showAddItem = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundColor(Color(hex: "0D47A1"))
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                if let quoteId = viewModel.quote?.id {
                    AddQuoteItemSheet(quoteId: quoteId, viewModel: viewModel)
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
                    .foregroundColor(Color(hex: "64748B"))

                Text("Cotizacion")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))
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
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Items")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "64748B"))

                Spacer()

                Text("\(viewModel.items.count) items")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "94A3B8"))
            }

            if viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "CBD5E1"))

                    Text("Agrega items a la cotizacion")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "94A3B8"))

                    Button {
                        showAddItem = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Agregar Item")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "0D47A1"))
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
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Totals Section

    private func totalsSection(_ quote: Quote) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Subtotal")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "64748B"))
                Spacer()
                Text(viewModel.formatCurrency(quote.subtotal))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "0D2137"))
            }

            if quote.discountAmount > 0 {
                HStack {
                    Text("Descuento")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "64748B"))
                    Spacer()
                    Text("-\(viewModel.formatCurrency(quote.discountAmount))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "22C55E"))
                }
            }

            HStack {
                Text("ITBIS (\(NSDecimalNumber(decimal: quote.taxRate).intValue)%)")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "64748B"))
                Spacer()
                Text(viewModel.formatCurrency(quote.taxAmount))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "0D2137"))
            }

            Divider()

            HStack {
                Text("Total")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "0D2137"))
                Spacer()
                Text(viewModel.formatCurrency(quote.total))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "0D47A1"))
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Actions Section

    private func actionsSection(_ quote: Quote) -> some View {
        VStack(spacing: 12) {
            if !viewModel.items.isEmpty {
                Button {
                    Task {
                        await viewModel.updateStatus(.sent)
                    }
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Enviar Cotizacion")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "0D47A1"))
                    .cornerRadius(26)
                }
            }
        }
        .padding(.top, 8)
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
                .foregroundColor(Color(hex: "0D47A1"))
                .frame(width: 32, height: 32)
                .background(Color(hex: "E3F2FD"))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "0D2137"))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text("\(NSDecimalNumber(decimal: item.quantity).intValue) x \(viewModel.formatCurrency(item.unitPrice))")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "64748B"))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(viewModel.formatCurrency(item.totalPrice))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "0D2137"))

                HStack(spacing: 12) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "64748B"))
                    }

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "EF4444"))
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .confirmationDialog("Eliminar item?", isPresented: $showDeleteConfirm) {
            Button("Eliminar", role: .destructive) {
                Task {
                    await viewModel.deleteItem(itemId: item.id)
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }
}

// MARK: - Add Quote Item Sheet

struct AddQuoteItemSheet: View {
    @Environment(\.dismiss) var dismiss

    let quoteId: UUID
    let viewModel: QuoteViewModel

    @State private var description = ""
    @State private var itemType: QuoteItemType = .service
    @State private var quantity = "1"
    @State private var unitPrice = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $itemType) {
                        ForEach(QuoteItemType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Descripcion") {
                    TextField("Descripcion del item", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Precio") {
                    HStack {
                        Text("Cantidad")
                        Spacer()
                        TextField("1", text: $quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Text("Precio unitario")
                        Spacer()
                        Text("RD$")
                            .foregroundColor(Color(hex: "64748B"))
                        TextField("0.00", text: $unitPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                if let total = calculatedTotal {
                    Section {
                        HStack {
                            Text("Total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(viewModel.formatCurrency(total))
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "0D47A1"))
                        }
                    }
                }
            }
            .navigationTitle("Agregar Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "64748B"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Agregar") {
                        Task {
                            await addItem()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "0D47A1"))
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
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
                Section("Descripcion") {
                    TextField("Descripcion del item", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Precio") {
                    HStack {
                        Text("Cantidad")
                        Spacer()
                        TextField("1", text: $quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Text("Precio unitario")
                        Spacer()
                        Text("RD$")
                            .foregroundColor(Color(hex: "64748B"))
                        TextField("0.00", text: $unitPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                if let total = calculatedTotal {
                    Section {
                        HStack {
                            Text("Total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(viewModel.formatCurrency(total))
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "0D47A1"))
                        }
                    }
                }
            }
            .navigationTitle("Editar Item")
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
                        Task {
                            await updateItem()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "0D47A1"))
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
            .navigationTitle("Estado")
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

#Preview {
    QuoteDetailView(
        orderId: UUID(),
        workshopId: UUID(),
        orderNumber: "ORD-0001"
    )
}

import SwiftUI

struct CustomersView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var viewModel = CustomersViewModel()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var searchText = ""
    @State private var showNewCustomer = false

    // iPad selection state
    @State private var selectedCustomerForIPad: Customer?

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad: Split View
                iPadLayout
            } else {
                // iPhone: Layout original
                iPhoneLayout
            }
        }
        .navigationTitle(L10n.Customers.title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showNewCustomer) {
            NewCustomerSheet(viewModel: viewModel)
        }
        .task {
            if let workshopId = sessionStore.workshop?.id {
                await viewModel.loadCustomers(workshopId: workshopId)
            }
        }
    }

    // MARK: - iPad Layout (Split View)

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            // Left: Customers List
            customersListPanel
                .frame(width: 380)
                .background(AxerColors.background)

            Divider()

            // Right: Customer Detail
            if let customer = selectedCustomerForIPad {
                CustomerDetailInline(
                    customer: Binding(
                        get: { customer },
                        set: { selectedCustomerForIPad = $0 }
                    ),
                    viewModel: viewModel,
                    onDelete: { selectedCustomerForIPad = nil }
                )
                .id(customer.id)
                .frame(maxWidth: .infinity)
            } else {
                // Placeholder when no customer is selected
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 60))
                        .foregroundColor(AxerColors.textTertiary)

                    Text(L10n.Customers.selectCustomer)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AxerColors.textSecondary)

                    Text(L10n.Customers.selectCustomerHint)
                        .font(.system(size: 14))
                        .foregroundColor(AxerColors.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AxerColors.background)
            }
        }
    }

    private var customersListPanel: some View {
        ZStack {
            AxerColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                searchBar

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.filteredCustomers(searchText: searchText).isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredCustomers(searchText: searchText)) { customer in
                                Button {
                                    selectedCustomerForIPad = customer
                                } label: {
                                    CustomerRowContent(customer: customer)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    selectedCustomerForIPad?.id == customer.id ? AxerColors.primary : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }

            // Floating button
            floatingButton
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        ZStack {
            AxerColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                searchBar

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.filteredCustomers(searchText: searchText).isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredCustomers(searchText: searchText)) { customer in
                                CustomerRow(customer: customer, viewModel: viewModel)
                            }
                        }
                        .padding(16)
                    }
                }
            }

            // Floating button
            floatingButton
        }
    }

    // MARK: - Shared Components

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AxerColors.textTertiary)

            TextField(L10n.Customers.searchPlaceholder, text: $searchText)
                .font(.system(size: 16))
                .foregroundColor(AxerColors.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AxerColors.textTertiary)
                }
            }
        }
        .padding(12)
        .background(AxerColors.surface)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var floatingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showNewCustomer = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                        Text(L10n.Customers.new)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(AxerColors.textInverse)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(AxerColors.buttonPrimary)
                    .cornerRadius(28)
                    .shadow(color: AxerColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .padding(20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundColor(AxerColors.textTertiary)

            Text(L10n.Customers.emptyTitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(AxerColors.textSecondary)

            Text(L10n.Customers.emptySubtitle)
                .font(.system(size: 14))
                .foregroundColor(AxerColors.textTertiary)
        }
    }
}

// MARK: - Customer Row

struct CustomerRow: View {
    let customer: Customer
    @ObservedObject var viewModel: CustomersViewModel
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
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

                    if let phone = customer.phone, !phone.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 11))
                            Text(phone)
                        }
                        .font(.system(size: 13))
                        .foregroundColor(AxerColors.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AxerColors.textTertiary)
            }
            .padding(16)
            .background(AxerColors.surface)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            CustomerDetailSheet(customer: customer, viewModel: viewModel)
        }
    }
}

// MARK: - Customer Row Content (for iPad list)

struct CustomerRowContent: View {
    let customer: Customer

    var body: some View {
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

                if let phone = customer.phone, !phone.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 11))
                        Text(phone)
                    }
                    .font(.system(size: 13))
                    .foregroundColor(AxerColors.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AxerColors.textTertiary)
        }
        .padding(16)
        .background(AxerColors.surface)
        .cornerRadius(12)
    }
}

// MARK: - Customer Detail Inline (for iPad)

struct CustomerDetailInline: View {
    @Binding var customer: Customer
    @ObservedObject var viewModel: CustomersViewModel
    var onDelete: () -> Void

    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    var body: some View {
        List {
            Section {
                HStack {
                    Circle()
                        .fill(AxerColors.primaryLight)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(customer.initials)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(AxerColors.primary)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(customer.name)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AxerColors.textPrimary)

                        if let date = customer.createdAt {
                            Text(L10n.Customers.customerSince(date.formatted(.dateTime.month(.wide).year())))
                                .font(.system(size: 14))
                                .foregroundColor(AxerColors.textSecondary)
                        }
                    }
                    .padding(.leading, 8)
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)
            }

            Section(L10n.Customers.sectionContact) {
                if let phone = customer.phone, !phone.isEmpty {
                    Button {
                        if let url = URL(string: "tel:\(phone)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label(phone, systemImage: "phone.fill")
                    }
                }

                if let email = customer.email, !email.isEmpty {
                    Button {
                        if let url = URL(string: "mailto:\(email)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label(email, systemImage: "envelope.fill")
                    }
                }

                if (customer.phone == nil || customer.phone?.isEmpty == true) &&
                   (customer.email == nil || customer.email?.isEmpty == true) {
                    Text(L10n.Customers.noContactInfo)
                        .foregroundColor(AxerColors.textTertiary)
                }
            }

            if let notes = customer.notes, !notes.isEmpty {
                Section(L10n.Customers.sectionNotes) {
                    Text(notes)
                        .foregroundColor(AxerColors.textSecondary)
                }
            }

            // Actions Section
            Section {
                Button {
                    showEditSheet = true
                } label: {
                    Label(L10n.Customers.edit, systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label(L10n.Customers.delete, systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(AxerColors.background)
        .sheet(isPresented: $showEditSheet) {
            EditCustomerSheet(customer: $customer, viewModel: viewModel)
        }
        .alert(L10n.Customers.deleteConfirmTitle, isPresented: $showDeleteAlert) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Common.delete, role: .destructive) {
                Task {
                    if await viewModel.deleteCustomer(customerId: customer.id) {
                        onDelete()
                    }
                }
            }
        } message: {
            Text(L10n.Customers.deleteConfirmMessage)
        }
    }
}

// MARK: - New Customer Sheet

struct NewCustomerSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionStore: SessionStore
    @ObservedObject var viewModel: CustomersViewModel

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.Customers.namePlaceholder, text: $name)
                    TextField(L10n.Customers.phonePlaceholder, text: $phone)
                        .keyboardType(.phonePad)
                    TextField(L10n.Customers.emailPlaceholder, text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Text(L10n.Common.requiredField)
                        .font(.system(size: 12))
                        .foregroundColor(AxerColors.textTertiary)
                }
            }
            .navigationTitle(L10n.Customers.new)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                    .foregroundColor(AxerColors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await saveCustomer()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(L10n.Common.save)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveCustomer() async {
        guard let workshopId = sessionStore.workshop?.id else { return }

        isSaving = true

        if await viewModel.createCustomer(
            workshopId: workshopId,
            name: name.trimmingCharacters(in: .whitespaces),
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email
        ) != nil {
            dismiss()
        }

        isSaving = false
    }
}

// MARK: - Customer Detail Sheet

struct CustomerDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @State var customer: Customer
    @ObservedObject var viewModel: CustomersViewModel
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Circle()
                            .fill(AxerColors.primaryLight)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Text(customer.initials)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(AxerColors.primary)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(customer.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AxerColors.textPrimary)

                            if let date = customer.createdAt {
                                Text(L10n.Customers.customerSince(date.formatted(.dateTime.month(.wide).year())))
                                    .font(.system(size: 13))
                                    .foregroundColor(AxerColors.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section(L10n.Customers.sectionContact) {
                    if let phone = customer.phone, !phone.isEmpty {
                        Button {
                            if let url = URL(string: "tel:\(phone)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label(phone, systemImage: "phone.fill")
                        }
                    }

                    if let email = customer.email, !email.isEmpty {
                        Button {
                            if let url = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label(email, systemImage: "envelope.fill")
                        }
                    }

                    if (customer.phone == nil || customer.phone?.isEmpty == true) &&
                       (customer.email == nil || customer.email?.isEmpty == true) {
                        Text(L10n.Customers.noContactInfo)
                            .foregroundColor(AxerColors.textTertiary)
                    }
                }

                if let notes = customer.notes, !notes.isEmpty {
                    Section(L10n.Customers.sectionNotes) {
                        Text(notes)
                            .foregroundColor(AxerColors.textSecondary)
                    }
                }

                // Actions Section
                Section {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label(L10n.Customers.edit, systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label(L10n.Customers.delete, systemImage: "trash")
                    }
                }
            }
            .navigationTitle(L10n.Customers.detailTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditCustomerSheet(customer: $customer, viewModel: viewModel)
            }
            .alert(L10n.Customers.deleteConfirmTitle, isPresented: $showDeleteAlert) {
                Button(L10n.Common.cancel, role: .cancel) {}
                Button(L10n.Common.delete, role: .destructive) {
                    Task {
                        if await viewModel.deleteCustomer(customerId: customer.id) {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text(L10n.Customers.deleteConfirmMessage)
            }
        }
    }
}

// MARK: - Edit Customer Sheet

struct EditCustomerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var customer: Customer
    @ObservedObject var viewModel: CustomersViewModel

    @State private var name: String
    @State private var phone: String
    @State private var email: String
    @State private var notes: String
    @State private var isSaving = false

    init(customer: Binding<Customer>, viewModel: CustomersViewModel) {
        self._customer = customer
        self.viewModel = viewModel
        _name = State(initialValue: customer.wrappedValue.name)
        _phone = State(initialValue: customer.wrappedValue.phone ?? "")
        _email = State(initialValue: customer.wrappedValue.email ?? "")
        _notes = State(initialValue: customer.wrappedValue.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Customers.sectionInfo) {
                    TextField(L10n.Customers.namePlaceholder, text: $name)
                    TextField(L10n.Customers.phonePlaceholder, text: $phone)
                        .keyboardType(.phonePad)
                    TextField(L10n.Customers.emailPlaceholder, text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section(L10n.Customers.sectionNotes) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(L10n.Customers.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                    .foregroundColor(AxerColors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await saveCustomer()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(L10n.Common.save)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func saveCustomer() async {
        isSaving = true

        let success = await viewModel.updateCustomer(
            customerId: customer.id,
            name: name.trimmingCharacters(in: .whitespaces),
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            notes: notes.isEmpty ? nil : notes
        )

        if success {
            // Update local binding
            customer.name = name.trimmingCharacters(in: .whitespaces)
            customer.phone = phone.isEmpty ? nil : phone
            customer.email = email.isEmpty ? nil : email
            customer.notes = notes.isEmpty ? nil : notes
            dismiss()
        }

        isSaving = false
    }
}

#Preview {
    NavigationStack {
        CustomersView()
            .environmentObject(SessionStore())
    }
}

import SwiftUI

struct WorkshopEditView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionStore: SessionStore

    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var orderPrefix: String = ""

    // Tax & Currency
    @State private var taxName: String = ""
    @State private var taxRate: String = ""
    @State private var currencySymbol: String = ""
    @State private var currencyCode: String = ""

    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let supabase = SupabaseClient.shared

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.WorkshopEdit.infoSection) {
                    TextField(L10n.WorkshopEdit.workshopName, text: $name)

                    TextField(L10n.WorkshopEdit.phone, text: $phone)
                        .keyboardType(.phonePad)

                    TextField(L10n.WorkshopEdit.address, text: $address)

                    TextField(L10n.WorkshopEdit.orderPrefix, text: $orderPrefix)
                        .textInputAutocapitalization(.characters)
                }

                Section(L10n.WorkshopEdit.fiscalSection) {
                    HStack {
                        Text(L10n.WorkshopEdit.taxName)
                        Spacer()
                        TextField(L10n.WorkshopEdit.taxNamePlaceholder, text: $taxName)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    HStack {
                        Text(L10n.WorkshopEdit.taxRate)
                        Spacer()
                        TextField(L10n.WorkshopEdit.taxRatePlaceholder, text: $taxRate)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section(L10n.WorkshopEdit.currencySection) {
                    HStack {
                        Text(L10n.WorkshopEdit.currencySymbol)
                        Spacer()
                        TextField(L10n.WorkshopEdit.currencySymbolPlaceholder, text: $currencySymbol)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Text(L10n.WorkshopEdit.currencyCode)
                        Spacer()
                        TextField(L10n.WorkshopEdit.currencyCodePlaceholder, text: $currencyCode)
                            .textInputAutocapitalization(.characters)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section {
                    Button {
                        applyPreset(.dominicanRepublic)
                    } label: {
                        Label(L10n.WorkshopEdit.presetDR, systemImage: "flag")
                    }

                    Button {
                        applyPreset(.mexico)
                    } label: {
                        Label(L10n.WorkshopEdit.presetMX, systemImage: "flag")
                    }

                    Button {
                        applyPreset(.usa)
                    } label: {
                        Label(L10n.WorkshopEdit.presetUS, systemImage: "flag")
                    }
                } header: {
                    Text(L10n.WorkshopEdit.presetsSection)
                } footer: {
                    Text(L10n.WorkshopEdit.presetsFooter)
                }
            }
            .navigationTitle(L10n.WorkshopEdit.title)
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
                            await saveWorkshop()
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
            .alert(L10n.Common.error, isPresented: $showError) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadCurrentValues()
            }
        }
    }

    private func loadCurrentValues() {
        guard let workshop = sessionStore.workshop else { return }

        name = workshop.name
        phone = workshop.phone ?? ""
        address = workshop.address ?? ""
        orderPrefix = workshop.orderPrefix

        taxName = workshop.taxName ?? "IVA"
        taxRate = workshop.taxRate.map { "\($0)" } ?? "0"
        currencySymbol = workshop.currencySymbol ?? "$"
        currencyCode = workshop.currencyCode ?? workshop.currency
    }

    private func applyPreset(_ preset: RegionalPreset) {
        taxName = preset.taxName
        taxRate = "\(preset.taxRate)"
        currencySymbol = preset.currencySymbol
        currencyCode = preset.currencyCode
    }

    private func saveWorkshop() async {
        guard let workshopId = sessionStore.workshop?.id else { return }

        isSaving = true

        struct WorkshopUpdate: Encodable {
            let name: String
            let phone: String?
            let address: String?
            let order_prefix: String
            let tax_name: String
            let tax_rate: Decimal
            let currency_symbol: String
            let currency_code: String
        }

        do {
            let rate = Decimal(string: taxRate) ?? 0

            let data = WorkshopUpdate(
                name: name.trimmingCharacters(in: .whitespaces),
                phone: phone.isEmpty ? nil : phone,
                address: address.isEmpty ? nil : address,
                order_prefix: orderPrefix.isEmpty ? "ORD" : orderPrefix.uppercased(),
                tax_name: taxName.isEmpty ? "IVA" : taxName,
                tax_rate: rate,
                currency_symbol: currencySymbol.isEmpty ? "$" : currencySymbol,
                currency_code: currencyCode.isEmpty ? "USD" : currencyCode.uppercased()
            )

            try await supabase.client
                .from("workshops")
                .update(data)
                .eq("id", value: workshopId.uuidString)
                .execute()

            // Reload session to get updated workshop
            await sessionStore.loadUserData()

            dismiss()
        } catch {
            errorMessage = "Error guardando: \(error.localizedDescription)"
            showError = true
            print("Error updating workshop: \(error)")
        }

        isSaving = false
    }
}

// MARK: - Regional Presets

enum RegionalPreset {
    case dominicanRepublic
    case mexico
    case usa
    case spain
    case colombia

    var taxName: String {
        switch self {
        case .dominicanRepublic: return "ITBIS"
        case .mexico: return "IVA"
        case .usa: return "Tax"
        case .spain: return "IVA"
        case .colombia: return "IVA"
        }
    }

    var taxRate: Decimal {
        switch self {
        case .dominicanRepublic: return 18
        case .mexico: return 16
        case .usa: return 0
        case .spain: return 21
        case .colombia: return 19
        }
    }

    var currencySymbol: String {
        switch self {
        case .dominicanRepublic: return "RD$"
        case .mexico: return "$"
        case .usa: return "$"
        case .spain: return "€"
        case .colombia: return "$"
        }
    }

    var currencyCode: String {
        switch self {
        case .dominicanRepublic: return "DOP"
        case .mexico: return "MXN"
        case .usa: return "USD"
        case .spain: return "EUR"
        case .colombia: return "COP"
        }
    }
}

#Preview {
    WorkshopEditView()
        .environmentObject(SessionStore())
}

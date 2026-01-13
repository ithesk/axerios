import Foundation
import SwiftUI

@MainActor
final class QuoteViewModel: ObservableObject {
    @Published var quote: Quote?
    @Published var items: [QuoteItem] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var workshop: Workshop?

    private let supabase = SupabaseClient.shared

    // MARK: - Workshop Configuration

    func setWorkshop(_ workshop: Workshop?) {
        self.workshop = workshop
    }

    var taxName: String {
        workshop?.displayTaxName ?? "IVA"
    }

    var defaultTaxRate: Decimal {
        workshop?.displayTaxRate ?? 0
    }

    var currencySymbol: String {
        workshop?.displayCurrencySymbol ?? "$"
    }

    var currencyCode: String {
        workshop?.displayCurrencyCode ?? "USD"
    }

    // MARK: - Load Quote for Order

    func loadQuote(orderId: UUID) async {
        isLoading = true
        error = nil

        do {
            let response: [Quote] = try await supabase.client
                .from("quotes")
                .select("*, items:quote_items(*)")
                .eq("order_id", value: orderId.uuidString)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            if let loadedQuote = response.first {
                self.quote = loadedQuote
                self.items = loadedQuote.items ?? []
            } else {
                self.quote = nil
                self.items = []
            }
        } catch {
            self.error = "Error cargando cotizacion"
            print("Error loading quote: \(error)")
        }

        isLoading = false
    }

    // MARK: - Create Quote

    func createQuote(orderId: UUID, workshopId: UUID) async -> Quote? {
        struct QuoteInsert: Encodable {
            let order_id: UUID
            let workshop_id: UUID
            let status: String
            let tax_rate: Decimal
        }

        do {
            let data = QuoteInsert(
                order_id: orderId,
                workshop_id: workshopId,
                status: QuoteStatus.draft.rawValue,
                tax_rate: defaultTaxRate  // Usa configuracion del workshop
            )

            let response: [Quote] = try await supabase.client
                .from("quotes")
                .insert(data)
                .select("*, items:quote_items(*)")
                .execute()
                .value

            if let newQuote = response.first {
                self.quote = newQuote
                self.items = []
                return newQuote
            }
        } catch {
            self.error = "Error creando cotizacion"
            print("Error creating quote: \(error)")
        }

        return nil
    }

    // MARK: - Add Item

    func addItem(
        quoteId: UUID,
        description: String,
        itemType: QuoteItemType,
        quantity: Decimal,
        unitPrice: Decimal
    ) async -> QuoteItem? {
        struct ItemInsert: Encodable {
            let quote_id: UUID
            let description: String
            let item_type: String
            let quantity: Decimal
            let unit_price: Decimal
            let total_price: Decimal
            let sort_order: Int
        }

        do {
            let totalPrice = quantity * unitPrice
            let sortOrder = items.count

            let data = ItemInsert(
                quote_id: quoteId,
                description: description,
                item_type: itemType.rawValue,
                quantity: quantity,
                unit_price: unitPrice,
                total_price: totalPrice,
                sort_order: sortOrder
            )

            let response: [QuoteItem] = try await supabase.client
                .from("quote_items")
                .insert(data)
                .select()
                .execute()
                .value

            if let newItem = response.first {
                items.append(newItem)
                // Reload quote to get updated totals
                if let orderId = quote?.orderId {
                    await loadQuote(orderId: orderId)
                }
                return newItem
            }
        } catch {
            self.error = "Error agregando item"
            print("Error adding item: \(error)")
        }

        return nil
    }

    // MARK: - Update Item

    func updateItem(
        itemId: UUID,
        description: String,
        quantity: Decimal,
        unitPrice: Decimal
    ) async -> Bool {
        struct ItemUpdate: Encodable {
            let description: String
            let quantity: Decimal
            let unit_price: Decimal
            let total_price: Decimal
        }

        do {
            let totalPrice = quantity * unitPrice

            let data = ItemUpdate(
                description: description,
                quantity: quantity,
                unit_price: unitPrice,
                total_price: totalPrice
            )

            try await supabase.client
                .from("quote_items")
                .update(data)
                .eq("id", value: itemId.uuidString)
                .execute()

            // Reload quote to get updated totals
            if let orderId = quote?.orderId {
                await loadQuote(orderId: orderId)
            }
            return true
        } catch {
            self.error = "Error actualizando item"
            print("Error updating item: \(error)")
            return false
        }
    }

    // MARK: - Delete Item

    func deleteItem(itemId: UUID) async -> Bool {
        do {
            try await supabase.client
                .from("quote_items")
                .delete()
                .eq("id", value: itemId.uuidString)
                .execute()

            items.removeAll { $0.id == itemId }

            // Reload quote to get updated totals
            if let orderId = quote?.orderId {
                await loadQuote(orderId: orderId)
            }
            return true
        } catch {
            self.error = "Error eliminando item"
            print("Error deleting item: \(error)")
            return false
        }
    }

    // MARK: - Update Quote Status

    func updateStatus(_ newStatus: QuoteStatus) async -> Bool {
        guard let quoteId = quote?.id else { return false }

        struct StatusUpdate: Encodable {
            let status: String
            let sent_at: String?
            let responded_at: String?
            let updated_at: String
        }

        do {
            let now = ISO8601DateFormatter().string(from: Date())
            var sentAt: String? = nil
            var respondedAt: String? = nil

            if newStatus == .sent && quote?.sentAt == nil {
                sentAt = now
            }
            if newStatus == .approved || newStatus == .rejected {
                respondedAt = now
            }

            let data = StatusUpdate(
                status: newStatus.rawValue,
                sent_at: sentAt,
                responded_at: respondedAt,
                updated_at: now
            )

            try await supabase.client
                .from("quotes")
                .update(data)
                .eq("id", value: quoteId.uuidString)
                .execute()

            quote?.status = newStatus
            return true
        } catch {
            self.error = "Error actualizando estado"
            print("Error updating status: \(error)")
            return false
        }
    }

    // MARK: - Update Tax Rate

    func updateTaxRate(_ taxRate: Decimal) async -> Bool {
        guard let quoteId = quote?.id else { return false }

        struct TaxUpdate: Encodable {
            let tax_rate: Decimal
            let updated_at: String
        }

        do {
            let data = TaxUpdate(
                tax_rate: taxRate,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase.client
                .from("quotes")
                .update(data)
                .eq("id", value: quoteId.uuidString)
                .execute()

            // Reload to get recalculated totals
            if let orderId = quote?.orderId {
                await loadQuote(orderId: orderId)
            }
            return true
        } catch {
            self.error = "Error actualizando impuesto"
            print("Error updating tax rate: \(error)")
            return false
        }
    }

    // MARK: - Update Discount

    func updateDiscount(_ discount: Decimal) async -> Bool {
        guard let quoteId = quote?.id else { return false }

        struct DiscountUpdate: Encodable {
            let discount_amount: Decimal
            let updated_at: String
        }

        do {
            let data = DiscountUpdate(
                discount_amount: discount,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase.client
                .from("quotes")
                .update(data)
                .eq("id", value: quoteId.uuidString)
                .execute()

            // Reload to get recalculated totals
            if let orderId = quote?.orderId {
                await loadQuote(orderId: orderId)
            }
            return true
        } catch {
            self.error = "Error actualizando descuento"
            print("Error updating discount: \(error)")
            return false
        }
    }

    // MARK: - Helpers

    func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.currencySymbol = currencySymbol
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "\(currencySymbol)0.00"
    }

    // MARK: - Share Quote

    func getShareURL() -> URL? {
        guard let token = quote?.publicToken else { return nil }
        // TODO: Configurar URL base desde settings
        let baseURL = "https://tu-dominio.com/quote"
        return URL(string: "\(baseURL)/\(token)")
    }

    func shareViaWhatsApp(customerPhone: String?, message: String) -> URL? {
        var phone = customerPhone?.replacingOccurrences(of: " ", with: "") ?? ""
        phone = phone.replacingOccurrences(of: "-", with: "")
        phone = phone.replacingOccurrences(of: "+", with: "")

        // Si no tiene codigo de pais, agregar uno por defecto
        if phone.count <= 10 {
            phone = "1" + phone  // Default US, cambiar segun workshop.countryCode
        }

        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/\(phone)?text=\(encodedMessage)")
    }

    func generateShareMessage(orderNumber: String, customerName: String) -> String {
        guard let quote = quote else { return "" }

        let total = formatCurrency(quote.total)
        let url = quote.publicURL ?? ""

        return """
        Hola \(customerName),

        Tu cotizacion para la orden \(orderNumber) esta lista.

        Total: \(total)

        Puedes ver los detalles y aprobarla aqui:
        \(url)

        Gracias por tu preferencia.
        """
    }
}

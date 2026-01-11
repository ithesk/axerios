import Foundation
import SwiftUI
import PhotosUI
import Supabase

@MainActor
final class OrdersViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var customers: [Customer] = []
    @Published var quotes: [Quote] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText = ""

    private let supabase = SupabaseClient.shared

    var filteredOrders: [Order] {
        if searchText.isEmpty {
            return orders
        }
        return orders.filter { order in
            order.orderNumber.localizedCaseInsensitiveContains(searchText) ||
            order.customer?.name.localizedCaseInsensitiveContains(searchText) == true ||
            order.customer?.phone?.localizedCaseInsensitiveContains(searchText) == true ||
            order.deviceImei?.localizedCaseInsensitiveContains(searchText) == true ||
            order.deviceBrand?.localizedCaseInsensitiveContains(searchText) == true ||
            order.deviceModel?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    var ordersByStatus: [OrderStatus: [Order]] {
        Dictionary(grouping: filteredOrders, by: { $0.status })
    }

    var activeOrders: [Order] {
        orders.filter { $0.status != .delivered }
    }

    // MARK: - Load Orders

    func loadOrders(workshopId: UUID) async {
        print("🔄 [Orders] ========== CARGANDO ORDENES ==========")
        print("🔄 [Orders] Workshop ID: \(workshopId)")

        isLoading = true
        error = nil

        do {
            let response: [Order] = try await supabase.client
                .from("orders")
                .select("*, customer:customers(*)")
                .eq("workshop_id", value: workshopId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            self.orders = response
            print("✅ [Orders] Órdenes cargadas: \(response.count)")
            for order in response {
                print("   - \(order.orderNumber): \(order.status.rawValue) - createdAt: \(String(describing: order.createdAt))")
            }
        } catch {
            self.error = "Error cargando ordenes: \(error.localizedDescription)"
            print("❌ [Orders] Error loading orders: \(error)")
        }

        isLoading = false
        print("🔄 [Orders] =====================================")
    }

    // MARK: - Load Customers

    func loadCustomers(workshopId: UUID) async {
        do {
            let response: [Customer] = try await supabase.client
                .from("customers")
                .select()
                .eq("workshop_id", value: workshopId.uuidString)
                .order("name")
                .execute()
                .value

            self.customers = response
        } catch {
            print("Error loading customers: \(error)")
        }
    }

    func searchCustomers(query: String, workshopId: UUID) async -> [Customer] {
        guard !query.isEmpty else { return [] }

        do {
            let response: [Customer] = try await supabase.client
                .from("customers")
                .select()
                .eq("workshop_id", value: workshopId.uuidString)
                .or("name.ilike.%\(query)%,phone.ilike.%\(query)%")
                .limit(10)
                .execute()
                .value

            return response
        } catch {
            print("Error searching customers: \(error)")
            return []
        }
    }

    // MARK: - Create Customer

    func createCustomer(
        workshopId: UUID,
        name: String,
        phone: String?,
        email: String?
    ) async -> Customer? {
        struct CustomerInsert: Encodable {
            let workshop_id: UUID
            let name: String
            let phone: String?
            let email: String?
        }

        print("🔵 [DEBUG] Intentando crear cliente...")
        print("🔵 [DEBUG] workshopId: \(workshopId)")
        print("🔵 [DEBUG] name: \(name)")
        print("🔵 [DEBUG] phone: \(phone ?? "nil")")

        do {
            let data = CustomerInsert(
                workshop_id: workshopId,
                name: name,
                phone: phone?.isEmpty == true ? nil : phone,
                email: email?.isEmpty == true ? nil : email
            )

            print("🔵 [DEBUG] Enviando insert a Supabase...")

            let response: [Customer] = try await supabase.client
                .from("customers")
                .insert(data)
                .select()
                .execute()
                .value

            print("🟢 [DEBUG] Respuesta recibida: \(response.count) clientes")

            if let customer = response.first {
                print("🟢 [DEBUG] Cliente creado: \(customer.name) - ID: \(customer.id)")
                customers.append(customer)
                return customer
            } else {
                print("🟡 [DEBUG] Respuesta vacía - no se creó el cliente")
            }
        } catch {
            self.error = "Error creando cliente: \(error.localizedDescription)"
            print("🔴 [ERROR] Error creating customer: \(error)")
        }

        return nil
    }

    // MARK: - Create Order

    func createOrder(
        workshopId: UUID,
        customerId: UUID,
        deviceType: DeviceType,
        deviceBrand: String?,
        deviceModel: String?,
        deviceColor: String?,
        deviceImei: String?,
        devicePassword: String?,
        devicePowersOn: Bool?,
        diagnostics: DeviceDiagnostics?,
        problemDescription: String,
        photos: [UIImage]
    ) async -> Order? {
        do {
            // 1. Get next order number
            let orderNumber: String = try await supabase.client
                .rpc("next_order_number", params: ["p_workshop_id": workshopId.uuidString])
                .execute()
                .value

            // 2. Create order
            struct OrderInsert: Encodable {
                let workshop_id: UUID
                let customer_id: UUID
                let order_number: String
                let device_type: String
                let device_brand: String?
                let device_model: String?
                let device_color: String?
                let device_imei: String?
                let device_password: String?
                let device_powers_on: Bool?
                let device_diagnostics: DeviceDiagnostics?
                let problem_description: String
                let status: String
            }

            let orderData = OrderInsert(
                workshop_id: workshopId,
                customer_id: customerId,
                order_number: orderNumber,
                device_type: deviceType.rawValue,
                device_brand: deviceBrand?.isEmpty == true ? nil : deviceBrand,
                device_model: deviceModel?.isEmpty == true ? nil : deviceModel,
                device_color: deviceColor?.isEmpty == true ? nil : deviceColor,
                device_imei: deviceImei?.isEmpty == true ? nil : deviceImei,
                device_password: devicePassword?.isEmpty == true ? nil : devicePassword,
                device_powers_on: devicePowersOn,
                device_diagnostics: diagnostics,
                problem_description: problemDescription,
                status: OrderStatus.received.rawValue
            )

            let orderResponse: [Order] = try await supabase.client
                .from("orders")
                .insert(orderData)
                .select("*, customer:customers(*)")
                .execute()
                .value

            guard let newOrder = orderResponse.first else {
                return nil
            }

            // 3. Upload photos if any
            for (index, image) in photos.enumerated() {
                await uploadPhoto(image: image, orderId: newOrder.id, workshopId: workshopId, index: index)
            }

            // 4. Add to local list
            orders.insert(newOrder, at: 0)

            return newOrder

        } catch {
            self.error = "Error creando orden"
            print("Error creating order: \(error)")
            return nil
        }
    }

    // MARK: - Upload Photo

    private func uploadPhoto(image: UIImage, orderId: UUID, workshopId: UUID, index: Int) async {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }

        let fileName = "\(workshopId.uuidString)/\(orderId.uuidString)/photo_\(index)_\(Date().timeIntervalSince1970).jpg"

        do {
            try await supabase.client.storage
                .from("order_photos")
                .upload(path: fileName, file: imageData, options: .init(contentType: "image/jpeg"))

            // Save photo reference
            struct PhotoInsert: Encodable {
                let order_id: UUID
                let storage_path: String
            }

            try await supabase.client
                .from("order_photos")
                .insert(PhotoInsert(order_id: orderId, storage_path: fileName))
                .execute()

        } catch {
            print("Error uploading photo: \(error)")
        }
    }

    // MARK: - Update Order Status

    func updateOrderStatus(orderId: UUID, newStatus: OrderStatus) async -> Bool {
        do {
            struct StatusUpdate: Encodable {
                let status: String
                let updated_at: String
            }

            var update = StatusUpdate(
                status: newStatus.rawValue,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase.client
                .from("orders")
                .update(update)
                .eq("id", value: orderId.uuidString)
                .execute()

            // Update local
            if let index = orders.firstIndex(where: { $0.id == orderId }) {
                orders[index].status = newStatus
            }

            return true
        } catch {
            self.error = "Error actualizando estado"
            print("Error updating status: \(error)")
            return false
        }
    }

    // MARK: - Tracking

    func generateTrackingToken(orderId: UUID) async -> String? {
        do {
            struct TokenParams: Encodable {
                let p_order_id: UUID
            }

            let token: String = try await supabase.client
                .rpc("generate_public_token", params: TokenParams(p_order_id: orderId))
                .execute()
                .value

            // Update local order
            if let index = orders.firstIndex(where: { $0.id == orderId }) {
                // Need to reload order to get updated token
                await reloadOrder(orderId: orderId)
            }

            print("✅ [Tracking] Token generado: \(token)")
            return token
        } catch {
            self.error = "Error generando link de seguimiento"
            print("❌ [Tracking] Error: \(error)")
            return nil
        }
    }

    func getTrackingURL(token: String) -> URL? {
        // URL de la página de tracking en Vercel
        let baseURL = "https://axer-tracking.vercel.app/"
        return URL(string: "\(baseURL)\(token)")
    }

    private func reloadOrder(orderId: UUID) async {
        do {
            let order: Order = try await supabase.client
                .from("orders")
                .select("*, customer:customers(*)")
                .eq("id", value: orderId.uuidString)
                .single()
                .execute()
                .value

            if let index = orders.firstIndex(where: { $0.id == orderId }) {
                orders[index] = order
            }
        } catch {
            print("Error reloading order: \(error)")
        }
    }

    // MARK: - Stats

    func orderStats() -> (today: Int, inProgress: Int, ready: Int, total: Int) {
        let calendar = Calendar.current

        // Debug: mostrar todas las órdenes y sus fechas
        print("📊 [Stats] ========== DEBUG ORDENES ==========")
        print("📊 [Stats] Total órdenes cargadas: \(orders.count)")

        for (index, order) in orders.enumerated() {
            let dateStr: String
            if let createdAt = order.createdAt {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                dateStr = formatter.string(from: createdAt)
                let isToday = calendar.isDateInToday(createdAt)
                print("📊 [Stats] Orden \(index + 1): \(order.orderNumber) - Fecha: \(dateStr) - ¿Hoy?: \(isToday) - Status: \(order.status.rawValue)")
            } else {
                print("📊 [Stats] Orden \(index + 1): \(order.orderNumber) - Fecha: NIL - Status: \(order.status.rawValue)")
            }
        }

        let today = orders.filter { order in
            guard let createdAt = order.createdAt else { return false }
            return calendar.isDateInToday(createdAt)
        }.count

        let inProgress = orders.filter {
            [.received, .diagnosing, .quoted, .approved, .inRepair].contains($0.status)
        }.count

        let ready = orders.filter { $0.status == .ready }.count

        print("📊 [Stats] Resultado: Hoy=\(today), EnProceso=\(inProgress), Listas=\(ready), Total=\(orders.count)")
        print("📊 [Stats] =====================================")

        return (today, inProgress, ready, orders.count)
    }

    // MARK: - Load Quotes

    func loadQuotes(workshopId: UUID) async {
        do {
            let response: [Quote] = try await supabase.client
                .from("quotes")
                .select("*, items:quote_items(*)")
                .eq("workshop_id", value: workshopId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            self.quotes = response
            print("✅ [Quotes] Cotizaciones cargadas: \(response.count)")
        } catch {
            print("❌ [Quotes] Error loading quotes: \(error)")
        }
    }

    // MARK: - Quote Stats

    /// Cotizaciones aprobadas hoy
    var todayApprovedQuotes: [Quote] {
        let calendar = Calendar.current
        return quotes.filter { quote in
            guard quote.status == .approved,
                  let respondedAt = quote.respondedAt else { return false }
            return calendar.isDateInToday(respondedAt)
        }
    }

    /// Monto total de cotizaciones aprobadas hoy
    var todayApprovedAmount: Decimal {
        todayApprovedQuotes.reduce(0) { $0 + $1.total }
    }

    /// Cotizaciones aprobadas este mes
    var monthApprovedQuotes: [Quote] {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return []
        }
        return quotes.filter { quote in
            guard quote.status == .approved,
                  let respondedAt = quote.respondedAt else { return false }
            return respondedAt >= startOfMonth
        }
    }

    /// Monto total de cotizaciones aprobadas este mes
    var monthApprovedAmount: Decimal {
        monthApprovedQuotes.reduce(0) { $0 + $1.total }
    }

    /// Órdenes completadas (entregadas) este mes
    var monthDeliveredOrders: [Order] {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return []
        }
        return orders.filter { order in
            guard order.status == .delivered,
                  let deliveredAt = order.deliveredAt else { return false }
            return deliveredAt >= startOfMonth
        }
    }

    /// Órdenes recibidas este mes
    var monthReceivedOrders: [Order] {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return []
        }
        return orders.filter { order in
            guard let createdAt = order.createdAt else { return false }
            return createdAt >= startOfMonth
        }
    }

    // MARK: - Load Status History

    func loadStatusHistory(orderId: UUID) async -> [OrderStatusHistory] {
        do {
            let response: [OrderStatusHistory] = try await supabase.client
                .from("order_status_history")
                .select("*, author:profiles!changed_by(id, full_name, role)")
                .eq("order_id", value: orderId.uuidString)
                .order("changed_at", ascending: false)
                .execute()
                .value

            return response
        } catch {
            print("Error loading status history: \(error)")
            return []
        }
    }

    // MARK: - Load Notes

    func loadNotes(orderId: UUID) async -> [OrderNote] {
        do {
            let response: [OrderNote] = try await supabase.client
                .from("order_notes")
                .select("*, author:profiles!created_by(id, full_name, role)")
                .eq("order_id", value: orderId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            return response
        } catch {
            print("Error loading notes: \(error)")
            return []
        }
    }

    // MARK: - Add Note

    func addNote(orderId: UUID, content: String, isInternal: Bool = true) async -> OrderNote? {
        struct NoteInsert: Encodable {
            let order_id: UUID
            let content: String
            let is_internal: Bool
        }

        do {
            let data = NoteInsert(
                order_id: orderId,
                content: content,
                is_internal: isInternal
            )

            let response: [OrderNote] = try await supabase.client
                .from("order_notes")
                .insert(data)
                .select("*, author:profiles!created_by(id, full_name, role)")
                .execute()
                .value

            return response.first
        } catch {
            self.error = "Error agregando nota"
            print("Error adding note: \(error)")
            return nil
        }
    }

    // MARK: - Load Activity Timeline

    func loadActivityTimeline(orderId: UUID) async -> [OrderActivity] {
        async let historyTask = loadStatusHistory(orderId: orderId)
        async let notesTask = loadNotes(orderId: orderId)

        let (history, notes) = await (historyTask, notesTask)

        var activities: [OrderActivity] = []

        activities.append(contentsOf: history.map { OrderActivity.fromStatusHistory($0) })
        activities.append(contentsOf: notes.map { OrderActivity.fromNote($0) })

        // Sort by date descending
        return activities.sorted { $0.createdAt > $1.createdAt }
    }
}

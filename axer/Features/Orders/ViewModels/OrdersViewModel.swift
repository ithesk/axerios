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
    @Published var isLoadingMore = false
    @Published var errorState: ErrorState?
    @Published var searchText = ""

    // MARK: - Pagination
    private let pageSize = 20
    private var currentPage = 0
    @Published var hasMorePages = true

    // Computed property for backward compatibility
    var error: String? {
        get { errorState?.message }
        set {
            if let msg = newValue {
                errorState = ErrorState(error: .unknown(msg))
            } else {
                errorState = nil
            }
        }
    }

    func clearError() {
        errorState = nil
    }

    func setError(_ error: Error) {
        errorState = ErrorState(from: error)
    }

    func setError(_ appError: AppError) {
        errorState = ErrorState(error: appError)
    }

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

    func loadOrders(workshopId: UUID, refresh: Bool = false) async {
        if refresh {
            currentPage = 0
            hasMorePages = true
        }

        isLoading = true
        clearError()

        do {
            let response: [Order] = try await supabase.client
                .from("orders_with_pending_questions")
                .select("*, customer:customers(*), owner:profiles!owner_user_id(id, full_name, role, avatar_url)")
                .eq("workshop_id", value: workshopId.uuidString)
                .order("created_at", ascending: false)
                .range(from: 0, to: pageSize - 1)
                .execute()
                .value

            self.orders = response
            self.hasMorePages = response.count >= pageSize
            self.currentPage = 0
        } catch {
            setError(error)
        }

        isLoading = false
    }

    /// Load more orders for infinite scroll
    func loadMoreOrders(workshopId: UUID) async {
        guard !isLoadingMore && hasMorePages else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1
        let from = nextPage * pageSize
        let to = from + pageSize - 1

        do {
            let response: [Order] = try await supabase.client
                .from("orders_with_pending_questions")
                .select("*, customer:customers(*), owner:profiles!owner_user_id(id, full_name, role, avatar_url)")
                .eq("workshop_id", value: workshopId.uuidString)
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value

            if response.isEmpty {
                hasMorePages = false
            } else {
                orders.append(contentsOf: response)
                currentPage = nextPage
                hasMorePages = response.count >= pageSize
            }
        } catch {
            // Silent fail for load more - don't show error
            print("Error loading more orders: \(error)")
        }

        isLoadingMore = false
    }

    /// Órdenes donde el usuario actual es el owner
    func myOrders(userId: UUID) -> [Order] {
        orders.filter { $0.ownerUserId == userId && $0.status != .delivered }
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

        do {
            let data = CustomerInsert(
                workshop_id: workshopId,
                name: name,
                phone: phone?.isEmpty == true ? nil : phone,
                email: email?.isEmpty == true ? nil : email
            )

            let response: [Customer] = try await supabase.client
                .from("customers")
                .insert(data)
                .select()
                .execute()
                .value

            if let customer = response.first {
                customers.append(customer)
                return customer
            }
        } catch {
            setError(error)
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

            // Haptic feedback for success
            HapticManager.success()

            return newOrder

        } catch {
            setError(error)
            HapticManager.error()
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

            HapticManager.success()
            return true
        } catch {
            setError(error)
            HapticManager.error()
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
            setError(error)
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
            setError(error)
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

    // MARK: - Owner Management (RPCs)

    /// Cambiar estado de orden con validación de permisos
    func changeOrderStatus(
        orderId: UUID,
        newStatus: OrderStatus,
        note: String? = nil,
        assignToUserId: UUID? = nil
    ) async -> Result<Bool, Error> {
        struct Params: Encodable {
            let p_order_id: UUID
            let p_new_status: String
            let p_note: String?
            let p_assign_to_user_id: UUID?
        }

        struct RPCResponse: Decodable {
            let success: Bool
            let error: String?
            let order_id: UUID?
            let new_owner_id: UUID?
        }

        do {
            let response: RPCResponse = try await supabase.client
                .rpc("change_order_status", params: Params(
                    p_order_id: orderId,
                    p_new_status: newStatus.rawValue,
                    p_note: note,
                    p_assign_to_user_id: assignToUserId
                ))
                .execute()
                .value

            if response.success {
                // Actualizar orden local
                if let index = orders.firstIndex(where: { $0.id == orderId }) {
                    orders[index].status = newStatus
                    if let newOwnerId = response.new_owner_id {
                        orders[index].ownerUserId = newOwnerId
                    }
                }
                print("✅ [Orders] Estado cambiado a \(newStatus.rawValue)")
                return .success(true)
            } else {
                let errorMsg = response.error ?? L10n.Error.unknown
                print("❌ [Orders] Error cambiando estado: \(errorMsg)")
                setError(.unknown(errorMsg))
                return .failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
            }
        } catch {
            print("❌ [Orders] Error RPC change_order_status: \(error)")
            setError(error)
            return .failure(error)
        }
    }

    /// Tomar una orden (convertirse en owner)
    func takeOrder(orderId: UUID) async -> Result<Bool, Error> {
        struct Params: Encodable {
            let p_order_id: UUID
        }

        struct RPCResponse: Decodable {
            let success: Bool
            let error: String?
            let new_owner_id: UUID?
        }

        do {
            let response: RPCResponse = try await supabase.client
                .rpc("take_order", params: Params(p_order_id: orderId))
                .execute()
                .value

            if response.success {
                // Actualizar orden local
                if let index = orders.firstIndex(where: { $0.id == orderId }),
                   let newOwnerId = response.new_owner_id {
                    orders[index].ownerUserId = newOwnerId
                }
                print("✅ [Orders] Orden tomada")
                return .success(true)
            } else {
                let errorMsg = response.error ?? L10n.Error.unknown
                print("❌ [Orders] Error tomando orden: \(errorMsg)")
                setError(.unknown(errorMsg))
                return .failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
            }
        } catch {
            print("❌ [Orders] Error RPC take_order: \(error)")
            setError(error)
            return .failure(error)
        }
    }

    /// Asignar orden a otro usuario (solo admin)
    func assignOrder(orderId: UUID, toUserId: UUID, note: String? = nil) async -> Result<Bool, Error> {
        struct Params: Encodable {
            let p_order_id: UUID
            let p_to_user_id: UUID
            let p_note: String?
        }

        struct RPCResponse: Decodable {
            let success: Bool
            let error: String?
            let new_owner_id: UUID?
        }

        do {
            let response: RPCResponse = try await supabase.client
                .rpc("assign_order", params: Params(
                    p_order_id: orderId,
                    p_to_user_id: toUserId,
                    p_note: note
                ))
                .execute()
                .value

            if response.success {
                // Actualizar orden local
                if let index = orders.firstIndex(where: { $0.id == orderId }),
                   let newOwnerId = response.new_owner_id {
                    orders[index].ownerUserId = newOwnerId
                }
                print("✅ [Orders] Orden asignada")
                return .success(true)
            } else {
                let errorMsg = response.error ?? L10n.Error.unknown
                print("❌ [Orders] Error asignando orden: \(errorMsg)")
                setError(.unknown(errorMsg))
                return .failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
            }
        } catch {
            print("❌ [Orders] Error RPC assign_order: \(error)")
            setError(error)
            return .failure(error)
        }
    }

    /// Cargar usuarios del workshop para selector de técnicos
    func loadWorkshopUsers(workshopId: UUID) async -> [Profile] {
        struct Params: Encodable {
            let p_workshop_id: UUID
        }

        do {
            let response: [Profile] = try await supabase.client
                .rpc("get_workshop_users", params: Params(p_workshop_id: workshopId))
                .execute()
                .value

            print("✅ [Orders] Usuarios del workshop: \(response.count)")
            return response
        } catch {
            print("❌ [Orders] Error cargando usuarios: \(error)")
            return []
        }
    }

    /// Verificar si el usuario puede modificar la orden
    func canModifyOrder(_ order: Order, currentUserId: UUID, isAdmin: Bool) -> Bool {
        // Admin siempre puede
        if isAdmin { return true }
        // Owner puede
        if order.ownerUserId == currentUserId { return true }
        // Si no tiene owner asignado, cualquiera puede (backwards compatibility)
        if order.ownerUserId == nil { return true }
        return false
    }

    // MARK: - QR Scanner - Find Order by Token

    /// Buscar orden por public_token (extraído de URL o directo)
    func findOrderByToken(_ input: String, workshopId: UUID) async -> Order? {
        // Extraer token de URL si es necesario
        let token = extractToken(from: input)

        guard !token.isEmpty else {
            print("❌ [Scanner] Token vacío")
            return nil
        }

        print("🔍 [Scanner] Buscando orden con token: \(token)")

        do {
            let response: [Order] = try await supabase.client
                .from("orders_with_pending_questions")
                .select("*, customer:customers(*), owner:profiles!owner_user_id(id, full_name, role, avatar_url)")
                .eq("workshop_id", value: workshopId.uuidString)
                .eq("public_token", value: token)
                .execute()
                .value

            if let order = response.first {
                print("✅ [Scanner] Orden encontrada: \(order.orderNumber)")
                return order
            } else {
                print("❌ [Scanner] No se encontró orden con token: \(token)")
                return nil
            }
        } catch {
            print("❌ [Scanner] Error buscando orden: \(error)")
            return nil
        }
    }

    /// Extraer token de URL o devolver input directo
    private func extractToken(from input: String) -> String {
        // Si es URL: https://axer-tracking.vercel.app/abc123 -> abc123
        if input.contains("axer-tracking.vercel.app/") {
            return input.components(separatedBy: "axer-tracking.vercel.app/").last ?? input
        }
        // Si es URL con / al final
        if input.hasPrefix("http") && input.contains("/") {
            return input.components(separatedBy: "/").last ?? input
        }
        // Devolver input directo (ya es token)
        return input
    }

    /// Buscar orden por número de orden (fallback)
    func findOrderByNumber(_ orderNumber: String, workshopId: UUID) async -> Order? {
        print("🔍 [Scanner] Buscando orden por número: \(orderNumber)")

        do {
            let response: [Order] = try await supabase.client
                .from("orders_with_pending_questions")
                .select("*, customer:customers(*), owner:profiles!owner_user_id(id, full_name, role, avatar_url)")
                .eq("workshop_id", value: workshopId.uuidString)
                .ilike("order_number", pattern: orderNumber)
                .execute()
                .value

            if let order = response.first {
                print("✅ [Scanner] Orden encontrada: \(order.orderNumber)")
                return order
            } else {
                print("❌ [Scanner] No se encontró orden con número: \(orderNumber)")
                return nil
            }
        } catch {
            print("❌ [Scanner] Error buscando orden: \(error)")
            return nil
        }
    }
}

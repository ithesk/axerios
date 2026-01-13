import Foundation

// MARK: - Workshop Service Model

struct WorkshopService: Codable, Identifiable {
    let id: UUID
    let workshopId: UUID
    var name: String
    var description: String?
    var itemType: String
    var defaultPrice: Decimal
    var isActive: Bool
    var useCount: Int
    var lastUsedAt: Date?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case workshopId = "workshop_id"
        case name
        case description
        case itemType = "item_type"
        case defaultPrice = "default_price"
        case isActive = "is_active"
        case useCount = "use_count"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var quoteItemType: QuoteItemType {
        QuoteItemType(rawValue: itemType) ?? .service
    }
}

// MARK: - Suggested Service (from RPC)

struct SuggestedService: Codable, Identifiable {
    let id: UUID
    let name: String
    let itemType: String
    let defaultPrice: Decimal
    let source: String
    let useCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case itemType = "item_type"
        case defaultPrice = "default_price"
        case source
        case useCount = "use_count"
    }

    var quoteItemType: QuoteItemType {
        QuoteItemType(rawValue: itemType) ?? .service
    }

    var isFromCatalog: Bool {
        source == "catalog"
    }
}

// MARK: - Service Catalog Store

@MainActor
final class ServiceCatalogStore: ObservableObject {
    @Published var services: [WorkshopService] = []
    @Published var suggestedServices: [SuggestedService] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseClient.shared

    // Default services for new workshops
    static let defaultServices: [(name: String, price: Decimal, type: String)] = [
        ("Cambio de pantalla", 3500, "part"),
        ("Cambio de batería", 1500, "part"),
        ("Diagnóstico", 500, "service"),
        ("Limpieza interna", 800, "service"),
        ("Cambio de puerto de carga", 1200, "part"),
        ("Reparación de placa", 2500, "service"),
        ("Cambio de tapa trasera", 1800, "part"),
        ("Actualización de software", 500, "service"),
        ("Cambio de conector flex", 900, "part"),
        ("Reparación Face ID", 3000, "service"),
    ]

    // MARK: - Load Services

    func loadServices(workshopId: UUID) async {
        isLoading = true
        error = nil

        do {
            let response: [WorkshopService] = try await supabase.client
                .from("workshop_services")
                .select()
                .eq("workshop_id", value: workshopId.uuidString)
                .eq("is_active", value: true)
                .order("use_count", ascending: false)
                .execute()
                .value

            self.services = response
        } catch {
            self.error = "Error cargando servicios"
            print("Error loading services: \(error)")
        }

        isLoading = false
    }

    // MARK: - Load Suggested Services (catalog + history)

    private struct SuggestedServicesParams: Encodable {
        let p_workshop_id: String
        let p_limit: Int
    }

    func loadSuggestedServices(workshopId: UUID) async {
        do {
            // Try to call RPC function
            let params = SuggestedServicesParams(
                p_workshop_id: workshopId.uuidString,
                p_limit: 12
            )
            let response: [SuggestedService] = try await supabase.client
                .rpc("get_suggested_services", params: params)
                .execute()
                .value

            self.suggestedServices = response

            // If no services, use defaults
            if suggestedServices.isEmpty {
                self.suggestedServices = Self.defaultServices.map { service in
                    SuggestedService(
                        id: UUID(),
                        name: service.name,
                        itemType: service.type,
                        defaultPrice: service.price,
                        source: "default",
                        useCount: 0
                    )
                }
            }
        } catch {
            // Fallback to catalog only or defaults
            print("Error loading suggested services: \(error)")
            await loadServices(workshopId: workshopId)

            if services.isEmpty {
                self.suggestedServices = Self.defaultServices.map { service in
                    SuggestedService(
                        id: UUID(),
                        name: service.name,
                        itemType: service.type,
                        defaultPrice: service.price,
                        source: "default",
                        useCount: 0
                    )
                }
            } else {
                self.suggestedServices = services.map { service in
                    SuggestedService(
                        id: service.id,
                        name: service.name,
                        itemType: service.itemType,
                        defaultPrice: service.defaultPrice,
                        source: "catalog",
                        useCount: service.useCount
                    )
                }
            }
        }
    }

    // MARK: - Add Service to Catalog

    func addService(
        workshopId: UUID,
        name: String,
        itemType: QuoteItemType,
        defaultPrice: Decimal
    ) async -> WorkshopService? {
        struct ServiceInsert: Encodable {
            let workshop_id: UUID
            let name: String
            let item_type: String
            let default_price: Decimal
        }

        do {
            let data = ServiceInsert(
                workshop_id: workshopId,
                name: name,
                item_type: itemType.rawValue,
                default_price: defaultPrice
            )

            let response: [WorkshopService] = try await supabase.client
                .from("workshop_services")
                .upsert(data, onConflict: "workshop_id,name")
                .select()
                .execute()
                .value

            if let newService = response.first {
                // Update local list
                if let index = services.firstIndex(where: { $0.id == newService.id }) {
                    services[index] = newService
                } else {
                    services.insert(newService, at: 0)
                }
                return newService
            }
        } catch {
            self.error = "Error guardando servicio"
            print("Error adding service: \(error)")
        }

        return nil
    }

    // MARK: - Update Service

    func updateService(
        serviceId: UUID,
        name: String,
        itemType: QuoteItemType,
        defaultPrice: Decimal,
        isActive: Bool
    ) async -> Bool {
        struct ServiceUpdate: Encodable {
            let name: String
            let item_type: String
            let default_price: Decimal
            let is_active: Bool
        }

        do {
            let data = ServiceUpdate(
                name: name,
                item_type: itemType.rawValue,
                default_price: defaultPrice,
                is_active: isActive
            )

            try await supabase.client
                .from("workshop_services")
                .update(data)
                .eq("id", value: serviceId.uuidString)
                .execute()

            // Update local
            if let index = services.firstIndex(where: { $0.id == serviceId }) {
                services[index].name = name
                services[index].itemType = itemType.rawValue
                services[index].defaultPrice = defaultPrice
                services[index].isActive = isActive

                if !isActive {
                    services.remove(at: index)
                }
            }

            return true
        } catch {
            self.error = "Error actualizando servicio"
            print("Error updating service: \(error)")
            return false
        }
    }

    // MARK: - Increment Usage

    func incrementUsage(serviceId: UUID) async {
        do {
            try await supabase.client
                .rpc("increment_service_usage", params: ["service_id": serviceId.uuidString])
                .execute()

            // Update local
            if let index = services.firstIndex(where: { $0.id == serviceId }) {
                services[index].useCount += 1
            }
        } catch {
            print("Error incrementing usage: \(error)")
        }
    }

    // MARK: - Delete Service

    func deleteService(serviceId: UUID) async -> Bool {
        do {
            try await supabase.client
                .from("workshop_services")
                .delete()
                .eq("id", value: serviceId.uuidString)
                .execute()

            services.removeAll { $0.id == serviceId }
            return true
        } catch {
            self.error = "Error eliminando servicio"
            print("Error deleting service: \(error)")
            return false
        }
    }

    // MARK: - Initialize Default Services

    func initializeDefaultServices(workshopId: UUID) async {
        for service in Self.defaultServices {
            _ = await addService(
                workshopId: workshopId,
                name: service.name,
                itemType: QuoteItemType(rawValue: service.type) ?? .service,
                defaultPrice: service.price
            )
        }
    }
}

import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    let workshopId: UUID?
    let fullName: String?
    let role: UserRole

    enum CodingKeys: String, CodingKey {
        case id
        case workshopId = "workshop_id"
        case fullName = "full_name"
        case role
    }
}

enum UserRole: String, Codable {
    case admin
    case technician

    var displayName: String {
        switch self {
        case .admin: return "Administrador"
        case .technician: return "Técnico"
        }
    }
}

struct Workshop: Codable, Identifiable {
    let id: UUID
    let name: String
    let phone: String?
    let currency: String
    let orderPrefix: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case phone
        case currency
        case orderPrefix = "order_prefix"
        case createdAt = "created_at"
    }
}

struct Invite: Codable, Identifiable {
    let id: UUID
    let workshopId: UUID
    let role: UserRole
    let token: String
    let createdBy: UUID?
    let expiresAt: Date
    let usedAt: Date?
    let usedBy: UUID?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case workshopId = "workshop_id"
        case role
        case token
        case createdBy = "created_by"
        case expiresAt = "expires_at"
        case usedAt = "used_at"
        case usedBy = "used_by"
        case createdAt = "created_at"
    }

    var isValid: Bool {
        usedAt == nil && expiresAt > Date()
    }

    var inviteCode: String {
        String(token.prefix(8)).uppercased()
    }
}

struct InviteValidation: Codable {
    let valid: Bool
    let workshopName: String?
    let role: String?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case valid
        case workshopName = "workshop_name"
        case role
        case expiresAt = "expires_at"
    }
}

struct TeamMember: Codable, Identifiable {
    let id: UUID
    let fullName: String?
    let role: UserRole

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case role
    }
}

// MARK: - Customer

struct Customer: Codable, Identifiable {
    let id: UUID
    let workshopId: UUID
    var name: String
    var phone: String?
    var email: String?
    var address: String?
    var notes: String?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case workshopId = "workshop_id"
        case name
        case phone
        case email
        case address
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Order

enum OrderStatus: String, Codable, CaseIterable {
    case received = "received"
    case diagnosing = "diagnosing"
    case quoted = "quoted"
    case approved = "approved"
    case inRepair = "in_repair"
    case ready = "ready"
    case delivered = "delivered"

    var displayName: String {
        switch self {
        case .received: return "Recibido"
        case .diagnosing: return "En Diagnostico"
        case .quoted: return "Cotizado"
        case .approved: return "Aprobado"
        case .inRepair: return "En Reparacion"
        case .ready: return "Listo"
        case .delivered: return "Entregado"
        }
    }

    var color: String {
        switch self {
        case .received: return "64748B"
        case .diagnosing: return "F59E0B"
        case .quoted: return "8B5CF6"
        case .approved: return "3B82F6"
        case .inRepair: return "F97316"
        case .ready: return "22C55E"
        case .delivered: return "6B7280"
        }
    }

    var icon: String {
        switch self {
        case .received: return "tray.and.arrow.down"
        case .diagnosing: return "magnifyingglass"
        case .quoted: return "dollarsign.circle"
        case .approved: return "checkmark.circle"
        case .inRepair: return "wrench.and.screwdriver"
        case .ready: return "checkmark.seal"
        case .delivered: return "hand.thumbsup"
        }
    }
}

enum DeviceType: String, Codable, CaseIterable {
    case phone = "phone"
    case tablet = "tablet"
    case laptop = "laptop"
    case other = "other"

    var displayName: String {
        switch self {
        case .phone: return "Telefono"
        case .tablet: return "Tablet"
        case .laptop: return "Laptop"
        case .other: return "Otro"
        }
    }

    var icon: String {
        switch self {
        case .phone: return "iphone"
        case .tablet: return "ipad"
        case .laptop: return "laptopcomputer"
        case .other: return "desktopcomputer"
        }
    }
}

struct Order: Codable, Identifiable {
    let id: UUID
    let workshopId: UUID
    let customerId: UUID
    let orderNumber: String

    // Device
    var deviceType: DeviceType
    var deviceBrand: String?
    var deviceModel: String?
    var deviceColor: String?
    var deviceImei: String?
    var devicePassword: String?

    // Problem
    var problemDescription: String

    // Status
    var status: OrderStatus

    // Tracking
    let publicToken: String?

    // Assignment
    var assignedTo: UUID?

    // Dates
    let receivedAt: Date?
    var estimatedCompletion: Date?
    var completedAt: Date?
    var deliveredAt: Date?

    let createdBy: UUID?
    let createdAt: Date?
    var updatedAt: Date?

    // Joined data (optional)
    var customer: Customer?

    enum CodingKeys: String, CodingKey {
        case id
        case workshopId = "workshop_id"
        case customerId = "customer_id"
        case orderNumber = "order_number"
        case deviceType = "device_type"
        case deviceBrand = "device_brand"
        case deviceModel = "device_model"
        case deviceColor = "device_color"
        case deviceImei = "device_imei"
        case devicePassword = "device_password"
        case problemDescription = "problem_description"
        case status
        case publicToken = "public_token"
        case assignedTo = "assigned_to"
        case receivedAt = "received_at"
        case estimatedCompletion = "estimated_completion"
        case completedAt = "completed_at"
        case deliveredAt = "delivered_at"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case customer
    }
}

struct OrderPhoto: Codable, Identifiable {
    let id: UUID
    let orderId: UUID
    let storagePath: String
    var caption: String?
    let takenAt: Date?
    let createdBy: UUID?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case storagePath = "storage_path"
        case caption
        case takenAt = "taken_at"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct OrderNote: Codable, Identifiable {
    let id: UUID
    let orderId: UUID
    var content: String
    var isInternal: Bool
    let createdBy: UUID?
    let createdAt: Date?

    // Joined data
    var author: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case content
        case isInternal = "is_internal"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case author = "author"
    }
}

// MARK: - Order Status History

struct OrderStatusHistory: Codable, Identifiable {
    let id: UUID
    let orderId: UUID
    let oldStatus: String?
    let newStatus: String
    let changedBy: UUID?
    let changedAt: Date?
    let note: String?

    // Joined data
    var author: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case oldStatus = "old_status"
        case newStatus = "new_status"
        case changedBy = "changed_by"
        case changedAt = "changed_at"
        case note
        case author
    }

    var oldOrderStatus: OrderStatus? {
        guard let oldStatus = oldStatus else { return nil }
        return OrderStatus(rawValue: oldStatus)
    }

    var newOrderStatus: OrderStatus? {
        OrderStatus(rawValue: newStatus)
    }
}

// MARK: - Order Activity (Combined timeline)

enum OrderActivityType: String {
    case statusChange = "status_change"
    case note = "note"
    case photo = "photo"
}

struct OrderActivity: Identifiable {
    let id: UUID
    let orderId: UUID
    let type: OrderActivityType
    let createdAt: Date
    let authorId: UUID?
    let authorName: String?

    // For status changes
    var oldStatus: OrderStatus?
    var newStatus: OrderStatus?

    // For notes
    var noteContent: String?
    var isInternalNote: Bool?

    static func fromStatusHistory(_ history: OrderStatusHistory) -> OrderActivity {
        OrderActivity(
            id: history.id,
            orderId: history.orderId,
            type: .statusChange,
            createdAt: history.changedAt ?? Date(),
            authorId: history.changedBy,
            authorName: history.author?.fullName,
            oldStatus: history.oldOrderStatus,
            newStatus: history.newOrderStatus,
            noteContent: history.note,
            isInternalNote: nil
        )
    }

    static func fromNote(_ note: OrderNote) -> OrderActivity {
        OrderActivity(
            id: note.id,
            orderId: note.orderId,
            type: .note,
            createdAt: note.createdAt ?? Date(),
            authorId: note.createdBy,
            authorName: note.author?.fullName,
            oldStatus: nil,
            newStatus: nil,
            noteContent: note.content,
            isInternalNote: note.isInternal
        )
    }
}

// MARK: - Quote

enum QuoteStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case sent = "sent"
    case approved = "approved"
    case rejected = "rejected"
    case expired = "expired"

    var displayName: String {
        switch self {
        case .draft: return "Borrador"
        case .sent: return "Enviada"
        case .approved: return "Aprobada"
        case .rejected: return "Rechazada"
        case .expired: return "Expirada"
        }
    }

    var color: String {
        switch self {
        case .draft: return "64748B"
        case .sent: return "3B82F6"
        case .approved: return "22C55E"
        case .rejected: return "EF4444"
        case .expired: return "9CA3AF"
        }
    }

    var icon: String {
        switch self {
        case .draft: return "doc.text"
        case .sent: return "paperplane.fill"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .expired: return "clock.badge.xmark"
        }
    }
}

enum QuoteItemType: String, Codable, CaseIterable {
    case service = "service"
    case part = "part"
    case other = "other"

    var displayName: String {
        switch self {
        case .service: return "Servicio"
        case .part: return "Repuesto"
        case .other: return "Otro"
        }
    }

    var icon: String {
        switch self {
        case .service: return "wrench.and.screwdriver"
        case .part: return "cpu"
        case .other: return "cube.box"
        }
    }
}

struct Quote: Codable, Identifiable {
    let id: UUID
    let orderId: UUID
    let workshopId: UUID

    // Totals
    var subtotal: Decimal
    var taxRate: Decimal
    var taxAmount: Decimal
    var discountAmount: Decimal
    var total: Decimal

    // Status
    var status: QuoteStatus

    // Notes
    var notes: String?
    var terms: String?

    // Dates
    var sentAt: Date?
    var respondedAt: Date?
    var expiresAt: Date?

    // Audit
    let createdBy: UUID?
    let createdAt: Date?
    var updatedAt: Date?

    // Joined data
    var items: [QuoteItem]?

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case workshopId = "workshop_id"
        case subtotal
        case taxRate = "tax_rate"
        case taxAmount = "tax_amount"
        case discountAmount = "discount_amount"
        case total
        case status
        case notes
        case terms
        case sentAt = "sent_at"
        case respondedAt = "responded_at"
        case expiresAt = "expires_at"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case items
    }
}

struct QuoteItem: Codable, Identifiable {
    let id: UUID
    let quoteId: UUID

    var description: String
    var itemType: QuoteItemType
    var quantity: Decimal
    var unitPrice: Decimal
    var totalPrice: Decimal
    var sortOrder: Int

    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case quoteId = "quote_id"
        case description
        case itemType = "item_type"
        case quantity
        case unitPrice = "unit_price"
        case totalPrice = "total_price"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

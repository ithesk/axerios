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
    var name: String
    var phone: String?
    var address: String?
    let currency: String
    var orderPrefix: String
    let createdAt: Date?

    // Configuracion regional (no hardcodeada)
    var taxName: String?
    var taxRate: Decimal?
    var currencySymbol: String?
    var currencyCode: String?
    var countryCode: String?
    var timezone: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case phone
        case address
        case currency
        case orderPrefix = "order_prefix"
        case createdAt = "created_at"
        case taxName = "tax_name"
        case taxRate = "tax_rate"
        case currencySymbol = "currency_symbol"
        case currencyCode = "currency_code"
        case countryCode = "country_code"
        case timezone
    }

    // Helpers con valores por defecto
    var displayTaxName: String { taxName ?? "IVA" }
    var displayTaxRate: Decimal { taxRate ?? 0 }
    var displayCurrencySymbol: String { currencySymbol ?? "$" }
    var displayCurrencyCode: String { currencyCode ?? currency }
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
        case .received: return "64748B"      // Gris slate
        case .diagnosing: return "D97706"    // Ámbar suave
        case .quoted: return "7C3AED"        // Violeta suave
        case .approved: return "2563EB"      // Azul
        case .inRepair: return "EA580C"      // Naranja suave
        case .ready: return "16A34A"         // Verde suave
        case .delivered: return "6B7280"     // Gris
        }
    }

    var icon: String {
        switch self {
        case .received: return "tray.and.arrow.down.fill"
        case .diagnosing: return "magnifyingglass.circle.fill"
        case .quoted: return "tag.fill"
        case .approved: return "checkmark.circle.fill"
        case .inRepair: return "wrench.and.screwdriver.fill"
        case .ready: return "checkmark.seal.fill"
        case .delivered: return "shippingbox.fill"
        }
    }

    var shortName: String {
        switch self {
        case .received: return "Recibido"
        case .diagnosing: return "Diagnóstico"
        case .quoted: return "Cotizado"
        case .approved: return "Aprobado"
        case .inRepair: return "Reparando"
        case .ready: return "Listo"
        case .delivered: return "Entregado"
        }
    }
}

enum DeviceType: String, Codable, CaseIterable {
    case iphone = "iphone"
    case android = "android"
    case laptop = "laptop"
    case tablet = "tablet"
    case watch = "watch"
    case other = "other"

    // Custom decoder to handle legacy "phone" value
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        // Map legacy values to new values
        switch rawValue {
        case "phone":
            self = .iphone  // Legacy: "phone" -> "iphone"
        case "iphone", "android", "laptop", "tablet", "watch", "other":
            self = DeviceType(rawValue: rawValue) ?? .other
        default:
            self = .other
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }

    var displayName: String {
        switch self {
        case .iphone: return "iPhone"
        case .android: return "Android"
        case .laptop: return "Laptop"
        case .tablet: return "Tablet"
        case .watch: return "Reloj"
        case .other: return "Otro"
        }
    }

    var icon: String {
        switch self {
        case .iphone: return "iphone.gen3"
        case .android: return "smartphone"
        case .laptop: return "laptopcomputer"
        case .tablet: return "ipad.gen2"
        case .watch: return "applewatch.watchface"
        case .other: return "display"
        }
    }

    /// Indica si este tipo de dispositivo es un teléfono móvil
    var isMobile: Bool {
        self == .iphone || self == .android
    }

    /// Marcas sugeridas por tipo de dispositivo
    var suggestedBrands: [String] {
        switch self {
        case .iphone:
            return ["Apple"]
        case .android:
            return ["Samsung", "Xiaomi", "Motorola", "Huawei", "OnePlus", "Google", "OPPO", "Realme", "Sony", "LG"]
        case .laptop:
            return ["Apple", "Dell", "HP", "Lenovo", "ASUS", "Acer", "MSI", "Microsoft", "Samsung", "Toshiba"]
        case .tablet:
            return ["Apple", "Samsung", "Lenovo", "Huawei", "Amazon", "Microsoft", "Xiaomi"]
        case .watch:
            return ["Apple", "Samsung", "Garmin", "Fitbit", "Huawei", "Amazfit", "Xiaomi"]
        case .other:
            return []
        }
    }
}

// MARK: - Diagnostic Check Status

enum DiagnosticCheckStatus: String, Codable, CaseIterable {
    case ok = "ok"
    case fail = "fail"
    case notTested = "not_tested"

    var displayName: String {
        switch self {
        case .ok: return "OK"
        case .fail: return "Falla"
        case .notTested: return "No probado"
        }
    }

    var icon: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .fail: return "xmark.circle.fill"
        case .notTested: return "minus.circle"
        }
    }

    var color: String {
        switch self {
        case .ok: return "16A34A"       // Verde suave
        case .fail: return "DC2626"     // Rojo suave
        case .notTested: return "94A3B8" // Gris
        }
    }
}

// MARK: - Device Diagnostics

struct DeviceDiagnostics: Codable {
    // Estado de encendido
    var powerStatus: Bool? // nil = no evaluado, true = enciende, false = no enciende

    // Diagnósticos comunes para móviles (iPhone/Android)
    var screen: DiagnosticCheckStatus = .notTested
    var touch: DiagnosticCheckStatus = .notTested
    var charging: DiagnosticCheckStatus = .notTested
    var battery: DiagnosticCheckStatus = .notTested
    var buttons: DiagnosticCheckStatus = .notTested

    // Solo si enciende - móviles
    var faceId: DiagnosticCheckStatus = .notTested      // Solo iPhone con Face ID
    var touchId: DiagnosticCheckStatus = .notTested     // Solo iPhone con Touch ID
    var frontCamera: DiagnosticCheckStatus = .notTested
    var rearCamera: DiagnosticCheckStatus = .notTested
    var microphone: DiagnosticCheckStatus = .notTested
    var speaker: DiagnosticCheckStatus = .notTested
    var wifi: DiagnosticCheckStatus = .notTested
    var bluetooth: DiagnosticCheckStatus = .notTested
    var cellular: DiagnosticCheckStatus = .notTested

    // Solo si no enciende
    var visibleDamage: DiagnosticCheckStatus = .notTested
    var waterDamage: DiagnosticCheckStatus = .notTested

    // Para Laptop/PC
    var keyboard: DiagnosticCheckStatus = .notTested
    var trackpad: DiagnosticCheckStatus = .notTested
    var ports: DiagnosticCheckStatus = .notTested
    var bootable: DiagnosticCheckStatus = .notTested

    // Para Smartwatch
    var pairing: DiagnosticCheckStatus = .notTested
    var heartSensor: DiagnosticCheckStatus = .notTested

    enum CodingKeys: String, CodingKey {
        case powerStatus = "power_status"
        case screen, touch, charging, battery, buttons
        case faceId = "face_id"
        case touchId = "touch_id"
        case frontCamera = "front_camera"
        case rearCamera = "rear_camera"
        case microphone, speaker, wifi, bluetooth, cellular
        case visibleDamage = "visible_damage"
        case waterDamage = "water_damage"
        case keyboard, trackpad, ports, bootable
        case pairing
        case heartSensor = "heart_sensor"
    }

    /// Retorna los campos relevantes según el tipo de dispositivo y si enciende
    static func relevantChecks(for deviceType: DeviceType, powersOn: Bool?) -> [DiagnosticField] {
        guard let powersOn = powersOn else {
            return [.powerStatus]
        }

        var fields: [DiagnosticField] = []

        switch deviceType {
        case .iphone, .android:
            if powersOn {
                // Checklist completo para móviles que encienden
                fields = [
                    .screen, .touch, .charging, .battery, .buttons,
                    .frontCamera, .rearCamera, .microphone, .speaker,
                    .wifi, .bluetooth, .cellular
                ]
                if deviceType == .iphone {
                    fields.insert(.faceId, at: 5)
                }
            } else {
                // Solo campos básicos si no enciende
                fields = [.screen, .charging, .visibleDamage, .waterDamage]
            }

        case .laptop:
            if powersOn {
                fields = [
                    .screen, .keyboard, .trackpad, .charging, .battery,
                    .ports, .speaker, .microphone, .wifi, .bluetooth, .bootable
                ]
            } else {
                fields = [.screen, .charging, .visibleDamage, .waterDamage]
            }

        case .tablet:
            if powersOn {
                fields = [
                    .screen, .touch, .charging, .battery, .buttons,
                    .frontCamera, .rearCamera, .speaker, .microphone,
                    .wifi, .bluetooth
                ]
            } else {
                fields = [.screen, .charging, .visibleDamage, .waterDamage]
            }

        case .watch:
            if powersOn {
                fields = [
                    .screen, .touch, .charging, .buttons, .pairing,
                    .heartSensor, .bluetooth
                ]
            } else {
                fields = [.screen, .charging, .visibleDamage, .waterDamage]
            }

        case .other:
            fields = [.screen, .charging, .visibleDamage]
        }

        return fields
    }
}

/// Campos de diagnóstico disponibles
enum DiagnosticField: String, CaseIterable {
    case powerStatus
    case screen
    case touch
    case charging
    case battery
    case buttons
    case faceId
    case touchId
    case frontCamera
    case rearCamera
    case microphone
    case speaker
    case wifi
    case bluetooth
    case cellular
    case visibleDamage
    case waterDamage
    case keyboard
    case trackpad
    case ports
    case bootable
    case pairing
    case heartSensor

    var displayName: String {
        switch self {
        case .powerStatus: return "¿Enciende?"
        case .screen: return "Pantalla"
        case .touch: return "Touch"
        case .charging: return "Carga"
        case .battery: return "Batería"
        case .buttons: return "Botones"
        case .faceId: return "Face ID"
        case .touchId: return "Touch ID"
        case .frontCamera: return "Cámara frontal"
        case .rearCamera: return "Cámara trasera"
        case .microphone: return "Micrófono"
        case .speaker: return "Altavoz"
        case .wifi: return "WiFi"
        case .bluetooth: return "Bluetooth"
        case .cellular: return "Red celular"
        case .visibleDamage: return "Golpes visibles"
        case .waterDamage: return "Daño por agua"
        case .keyboard: return "Teclado"
        case .trackpad: return "Trackpad"
        case .ports: return "Puertos"
        case .bootable: return "Inicia SO"
        case .pairing: return "Empareja"
        case .heartSensor: return "Sensor cardíaco"
        }
    }

    var icon: String {
        switch self {
        case .powerStatus: return "power"
        case .screen: return "rectangle.inset.filled"
        case .touch: return "hand.tap"
        case .charging: return "battery.100.bolt"
        case .battery: return "battery.75"
        case .buttons: return "button.horizontal"
        case .faceId: return "faceid"
        case .touchId: return "touchid"
        case .frontCamera: return "camera.fill"
        case .rearCamera: return "camera.fill"
        case .microphone: return "mic.fill"
        case .speaker: return "speaker.wave.2.fill"
        case .wifi: return "wifi"
        case .bluetooth: return "bolt.horizontal.fill"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .visibleDamage: return "exclamationmark.triangle.fill"
        case .waterDamage: return "drop.fill"
        case .keyboard: return "keyboard"
        case .trackpad: return "rectangle.and.hand.point.up.left.fill"
        case .ports: return "cable.connector"
        case .bootable: return "desktopcomputer"
        case .pairing: return "link"
        case .heartSensor: return "heart.fill"
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

    // Device Diagnostics (new)
    var devicePowersOn: Bool?
    var deviceDiagnostics: DeviceDiagnostics?

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
        case devicePowersOn = "device_powers_on"
        case deviceDiagnostics = "device_diagnostics"
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

    // Public sharing
    var publicToken: String?

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
        case publicToken = "public_token"
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

    /// URL publica para compartir la cotizacion
    var publicURL: String? {
        guard let token = publicToken else { return nil }
        // TODO: Cambiar por URL real de produccion
        return "https://tu-dominio.com/quote/\(token)"
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

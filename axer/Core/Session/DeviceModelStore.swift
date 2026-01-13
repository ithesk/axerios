import Foundation

/// Almacena y gestiona modelos de dispositivos con autocompletado inteligente
class DeviceModelStore: ObservableObject {
    static let shared = DeviceModelStore()

    private let userDefaultsKey = "savedDeviceModels"

    /// Modelos guardados por el usuario (tipo -> marca -> [modelos])
    @Published private(set) var customModels: [String: [String: [String]]] = [:]

    private init() {
        loadCustomModels()
    }

    // MARK: - Modelos Predefinidos

    /// Modelos predefinidos por tipo de dispositivo y marca
    static let predefinedModels: [DeviceType: [String: [String]]] = [
        .iphone: [
            "Apple": [
                "iPhone 16 Pro Max", "iPhone 16 Pro", "iPhone 16 Plus", "iPhone 16",
                "iPhone 15 Pro Max", "iPhone 15 Pro", "iPhone 15 Plus", "iPhone 15",
                "iPhone 14 Pro Max", "iPhone 14 Pro", "iPhone 14 Plus", "iPhone 14",
                "iPhone 13 Pro Max", "iPhone 13 Pro", "iPhone 13 mini", "iPhone 13",
                "iPhone 12 Pro Max", "iPhone 12 Pro", "iPhone 12 mini", "iPhone 12",
                "iPhone 11 Pro Max", "iPhone 11 Pro", "iPhone 11",
                "iPhone XS Max", "iPhone XS", "iPhone XR", "iPhone X",
                "iPhone SE (3ra gen)", "iPhone SE (2da gen)", "iPhone SE",
                "iPhone 8 Plus", "iPhone 8", "iPhone 7 Plus", "iPhone 7"
            ]
        ],
        .android: [
            "Samsung": [
                "Galaxy S24 Ultra", "Galaxy S24+", "Galaxy S24",
                "Galaxy S23 Ultra", "Galaxy S23+", "Galaxy S23",
                "Galaxy S22 Ultra", "Galaxy S22+", "Galaxy S22",
                "Galaxy S21 Ultra", "Galaxy S21+", "Galaxy S21",
                "Galaxy Z Fold 5", "Galaxy Z Fold 4", "Galaxy Z Flip 5", "Galaxy Z Flip 4",
                "Galaxy A54", "Galaxy A34", "Galaxy A24", "Galaxy A14",
                "Galaxy A53", "Galaxy A33", "Galaxy A23", "Galaxy A13"
            ],
            "Xiaomi": [
                "14 Ultra", "14 Pro", "14",
                "13 Ultra", "13 Pro", "13", "13 Lite",
                "12 Pro", "12", "12 Lite",
                "Redmi Note 13 Pro+", "Redmi Note 13 Pro", "Redmi Note 13",
                "Redmi Note 12 Pro+", "Redmi Note 12 Pro", "Redmi Note 12",
                "Redmi 13", "Redmi 12", "Redmi A3"
            ],
            "Motorola": [
                "Edge 50 Ultra", "Edge 50 Pro", "Edge 50",
                "Edge 40 Pro", "Edge 40", "Edge 40 Neo",
                "Moto G84", "Moto G73", "Moto G54", "Moto G34",
                "Moto G Power", "Moto G Stylus", "Moto G Play"
            ],
            "Huawei": [
                "P60 Pro", "P60", "P50 Pro", "P50",
                "Mate 60 Pro", "Mate 60", "Mate 50 Pro",
                "Nova 12", "Nova 11", "Nova 10"
            ],
            "OnePlus": [
                "12", "12R", "11", "11R",
                "Nord 3", "Nord CE 3", "Nord N30"
            ],
            "Google": [
                "Pixel 8 Pro", "Pixel 8", "Pixel 8a",
                "Pixel 7 Pro", "Pixel 7", "Pixel 7a",
                "Pixel 6 Pro", "Pixel 6", "Pixel 6a"
            ],
            "OPPO": [
                "Find X7 Ultra", "Find X7",
                "Reno 11 Pro", "Reno 11", "Reno 10 Pro",
                "A79", "A78", "A58"
            ],
            "Realme": [
                "GT 5 Pro", "GT 5", "GT Neo 5",
                "12 Pro+", "12 Pro", "12",
                "C55", "C53", "C51"
            ]
        ],
        .laptop: [
            "Apple": [
                "MacBook Pro 16\" M3 Max", "MacBook Pro 16\" M3 Pro",
                "MacBook Pro 14\" M3 Max", "MacBook Pro 14\" M3 Pro", "MacBook Pro 14\" M3",
                "MacBook Air 15\" M3", "MacBook Air 13\" M3",
                "MacBook Pro 16\" M2 Max", "MacBook Pro 14\" M2",
                "MacBook Air 15\" M2", "MacBook Air 13\" M2"
            ],
            "Dell": [
                "XPS 15", "XPS 13 Plus", "XPS 13",
                "Inspiron 15", "Inspiron 14", "Inspiron 13",
                "Latitude 5540", "Latitude 5440", "Latitude 7440",
                "G15 Gaming", "Alienware m16", "Alienware x14"
            ],
            "HP": [
                "Spectre x360 16", "Spectre x360 14",
                "Envy x360 15", "Envy x360 13",
                "Pavilion 15", "Pavilion 14",
                "EliteBook 840", "EliteBook 850",
                "Omen 16", "Victus 15"
            ],
            "Lenovo": [
                "ThinkPad X1 Carbon", "ThinkPad T14", "ThinkPad L14",
                "IdeaPad Slim 5", "IdeaPad 3",
                "Yoga 9i", "Yoga 7i", "Yoga Slim 7",
                "Legion Pro 7", "Legion 5", "LOQ 15"
            ],
            "ASUS": [
                "ZenBook Pro 16X", "ZenBook 14", "ZenBook S 13",
                "VivoBook Pro 15", "VivoBook 15",
                "ROG Zephyrus G14", "ROG Strix G16", "TUF Gaming A15"
            ],
            "Acer": [
                "Swift Go 14", "Swift 5", "Swift 3",
                "Aspire 5", "Aspire 3",
                "Predator Helios 16", "Nitro 5", "Nitro 16"
            ]
        ],
        .tablet: [
            "Apple": [
                "iPad Pro 13\" M4", "iPad Pro 11\" M4",
                "iPad Air 13\" M2", "iPad Air 11\" M2",
                "iPad (10ma gen)", "iPad (9na gen)",
                "iPad mini (6ta gen)"
            ],
            "Samsung": [
                "Galaxy Tab S9 Ultra", "Galaxy Tab S9+", "Galaxy Tab S9",
                "Galaxy Tab S8 Ultra", "Galaxy Tab S8+", "Galaxy Tab S8",
                "Galaxy Tab A9+", "Galaxy Tab A9", "Galaxy Tab A8"
            ],
            "Lenovo": [
                "Tab P12 Pro", "Tab P11 Pro", "Tab P11",
                "Tab M10 Plus", "Tab M9", "Tab M8"
            ],
            "Huawei": [
                "MatePad Pro 13.2", "MatePad Pro 11",
                "MatePad 11.5", "MatePad SE"
            ],
            "Xiaomi": [
                "Pad 6 Pro", "Pad 6", "Pad 5",
                "Redmi Pad Pro", "Redmi Pad SE"
            ]
        ],
        .watch: [
            "Apple": [
                "Apple Watch Ultra 2", "Apple Watch Ultra",
                "Apple Watch Series 9 45mm", "Apple Watch Series 9 41mm",
                "Apple Watch Series 8 45mm", "Apple Watch Series 8 41mm",
                "Apple Watch SE (2da gen) 44mm", "Apple Watch SE (2da gen) 40mm",
                "Apple Watch Series 7", "Apple Watch Series 6", "Apple Watch Series 5"
            ],
            "Samsung": [
                "Galaxy Watch 6 Classic", "Galaxy Watch 6",
                "Galaxy Watch 5 Pro", "Galaxy Watch 5",
                "Galaxy Watch 4 Classic", "Galaxy Watch 4"
            ],
            "Garmin": [
                "Fenix 7X", "Fenix 7", "Fenix 7S",
                "Forerunner 965", "Forerunner 265", "Forerunner 165",
                "Venu 3", "Venu 2 Plus", "Vivoactive 5"
            ],
            "Fitbit": [
                "Sense 2", "Versa 4", "Charge 6", "Inspire 3"
            ],
            "Huawei": [
                "Watch GT 4 Pro", "Watch GT 4", "Watch GT 3 Pro",
                "Watch Fit 3", "Watch Fit 2", "Band 8"
            ],
            "Amazfit": [
                "GTR 4", "GTS 4", "T-Rex Ultra",
                "Balance", "Bip 5", "Band 7"
            ]
        ],
        .other: [:]
    ]

    // MARK: - Public Methods

    /// Obtiene todos los modelos disponibles para un tipo y marca
    func getModels(for deviceType: DeviceType, brand: String) -> [String] {
        var models: [String] = []

        // Agregar modelos predefinidos
        if let brandModels = Self.predefinedModels[deviceType]?[brand] {
            models.append(contentsOf: brandModels)
        }

        // Agregar modelos personalizados
        if let customBrandModels = customModels[deviceType.rawValue]?[brand] {
            for model in customBrandModels {
                if !models.contains(model) {
                    models.append(model)
                }
            }
        }

        return models
    }

    /// Obtiene todas las marcas disponibles para un tipo de dispositivo
    func getBrands(for deviceType: DeviceType) -> [String] {
        var brands = Set(deviceType.suggestedBrands)

        // Agregar marcas predefinidas con modelos
        if let predefinedBrands = Self.predefinedModels[deviceType]?.keys {
            brands.formUnion(predefinedBrands)
        }

        // Agregar marcas personalizadas
        if let customBrands = customModels[deviceType.rawValue]?.keys {
            brands.formUnion(customBrands)
        }

        return Array(brands).sorted()
    }

    /// Guarda un nuevo modelo personalizado
    func saveModel(_ model: String, for deviceType: DeviceType, brand: String) {
        guard !model.isEmpty && !brand.isEmpty else { return }

        // Verificar si ya existe en predefinidos
        if let predefined = Self.predefinedModels[deviceType]?[brand],
           predefined.contains(model) {
            return
        }

        // Inicializar estructura si es necesario
        if customModels[deviceType.rawValue] == nil {
            customModels[deviceType.rawValue] = [:]
        }
        if customModels[deviceType.rawValue]?[brand] == nil {
            customModels[deviceType.rawValue]?[brand] = []
        }

        // Agregar si no existe
        if !(customModels[deviceType.rawValue]?[brand]?.contains(model) ?? false) {
            customModels[deviceType.rawValue]?[brand]?.append(model)
            saveCustomModels()
        }
    }

    /// Guarda una nueva marca personalizada
    func saveBrand(_ brand: String, for deviceType: DeviceType) {
        guard !brand.isEmpty else { return }

        if customModels[deviceType.rawValue] == nil {
            customModels[deviceType.rawValue] = [:]
        }

        if customModels[deviceType.rawValue]?[brand] == nil {
            customModels[deviceType.rawValue]?[brand] = []
            saveCustomModels()
        }
    }

    // MARK: - Persistence

    private func loadCustomModels() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([String: [String: [String]]].self, from: data) {
            customModels = decoded
        }
    }

    private func saveCustomModels() {
        if let encoded = try? JSONEncoder().encode(customModels) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
}

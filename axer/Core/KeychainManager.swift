import Foundation
import Security

enum KeychainManager {

    enum KeychainError: Error {
        case encodingFailed
        case decodingFailed
        case saveFailed(OSStatus)
        case deleteFailed(OSStatus)
        case notFound
        case unknown(OSStatus)
    }

    // MARK: - Save

    /// Guarda datos Codable en Keychain
    static func save<T: Codable>(_ item: T, forKey key: String) throws {
        guard let data = try? JSONEncoder().encode(item) else {
            throw KeychainError.encodingFailed
        }

        // Eliminar item existente primero
        try? delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.axer.app",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    // MARK: - Load

    /// Carga datos Codable desde Keychain
    static func load<T: Codable>(forKey key: String) throws -> T {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.axer.app",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            throw KeychainError.unknown(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.decodingFailed
        }

        guard let item = try? JSONDecoder().decode(T.self, from: data) else {
            throw KeychainError.decodingFailed
        }

        return item
    }

    // MARK: - Delete

    /// Elimina un item de Keychain
    static func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.axer.app"
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: - Exists

    /// Verifica si existe un item en Keychain
    static func exists(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.axer.app",
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

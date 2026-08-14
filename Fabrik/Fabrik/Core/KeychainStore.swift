import Foundation
import Security

/// Stores the user's fal API key in the system Keychain.
///
/// The key is the one genuinely sensitive value the app holds, and it belongs
/// to the user — Fabrik ships with no credentials of its own. `UserDefaults`
/// would leave it in plain text inside the app container, so it goes in the
/// Keychain instead.
///
/// `kSecAttrAccessibleAfterFirstUnlock` is used rather than the default so a
/// job kicked off before the device locks can still authenticate.
enum KeychainStore {
    /// Change this if you change the bundle identifier.
    private static let service = "com.fabrik.Fabrik.falKey"
    private static let account = "fal-api-key"

    static func save(_ value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete first: SecItemAdd fails with errSecDuplicateItem otherwise,
        // and an update-or-insert dance is more code for the same result.
        SecItemDelete(baseQuery() as CFDictionary)

        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    static func read() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

enum KeychainError: LocalizedError {
    case encodingFailed
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Could not encode the API key."
        case .unhandled(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "status \(status)"
            return "Keychain error: \(message)"
        }
    }
}

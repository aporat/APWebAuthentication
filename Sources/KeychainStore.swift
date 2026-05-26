import Foundation
import Security

/// Thin wrapper around the iOS Keychain (`kSecClassGenericPassword`) used to
/// persist OAuth credentials and other secrets.
///
/// Items are stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so
/// they survive reboots but are never included in iCloud or unencrypted device
/// backups and never leave the device.
enum KeychainStore {

    /// Service identifier used for all items written by this library.
    static let service = "com.apwebauthentication.credentials"

    enum KeychainError: Error {
        case unhandledStatus(OSStatus)
    }

    /// Writes `data` to the Keychain under `(category, account)`. Replaces any
    /// existing item with the same key.
    static func save(_ data: Data, account: String, category: String) throws {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: makeKey(account: account, category: category),
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(addStatus)
            }
        default:
            throw KeychainError.unhandledStatus(updateStatus)
        }
    }

    /// Reads the data stored under `(category, account)`, or `nil` if absent.
    static func load(account: String, category: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: makeKey(account: account, category: category),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledStatus(status)
        }
    }

    /// Removes the item stored under `(category, account)` if present.
    static func delete(account: String, category: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: makeKey(account: account, category: category),
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private static func makeKey(account: String, category: String) -> String {
        "\(category).\(account)"
    }
}

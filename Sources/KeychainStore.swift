import Foundation
@preconcurrency import KeychainAccess

/// Thin wrapper around the iOS Keychain (`kSecClassGenericPassword`) used to
/// persist OAuth credentials and other secrets.
///
/// Items are stored with `.afterFirstUnlockThisDeviceOnly`, so they survive
/// reboots but are never included in iCloud or unencrypted device backups and
/// never leave the device.
enum KeychainStore {

    /// Service identifier used for all items written by this library.
    static let service = "com.apwebauthentication.credentials"

    enum KeychainError: Error {
        case underlying(Swift.Error)
    }

    private static let keychain: Keychain = {
        Keychain(service: service)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
    }()

    /// Writes `data` to the Keychain under `(category, account)`. Replaces any
    /// existing item with the same key.
    static func save(_ data: Data, account: String, category: String) throws {
        do {
            try keychain.set(data, key: makeKey(account: account, category: category))
        } catch {
            throw KeychainError.underlying(error)
        }
    }

    /// Reads the data stored under `(category, account)`, or `nil` if absent.
    static func load(account: String, category: String) throws -> Data? {
        do {
            return try keychain.getData(makeKey(account: account, category: category))
        } catch {
            throw KeychainError.underlying(error)
        }
    }

    /// Removes the item stored under `(category, account)` if present.
    static func delete(account: String, category: String) throws {
        do {
            try keychain.remove(makeKey(account: account, category: category))
        } catch {
            throw KeychainError.underlying(error)
        }
    }

    private static func makeKey(account: String, category: String) -> String {
        "\(category).\(account)"
    }
}

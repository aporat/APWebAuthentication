import Foundation
import OSLog
import SwifterSwift

// MARK: - Codable HTTPCookie

/// Internal wrapper for encoding and decoding `HTTPCookie` objects.
private struct CodableHTTPCookie: Codable, Sendable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expiresDate: Date?
    let isSecure: Bool

    /// Creates a codable cookie from an `HTTPCookie`.
    init?(from cookie: HTTPCookie) {
        self.name = cookie.name
        self.value = cookie.value
        self.domain = cookie.domain
        self.path = cookie.path
        self.expiresDate = cookie.expiresDate
        self.isSecure = cookie.isSecure
    }

    /// Converts the codable cookie back to an `HTTPCookie`.
    var httpCookie: HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [:]
        properties[.name] = name
        properties[.value] = value
        properties[.domain] = domain
        properties[.path] = path
        properties[.expires] = expiresDate
        properties[.secure] = isSecure

        return HTTPCookie(properties: properties)
    }
}

// MARK: - Session Authentication

/// Session-based authentication manager using HTTP cookies.
///
/// Manages web-style authentication with cookies, session IDs, and CSRF tokens.
///
/// **Example Usage:**
/// ```swift
/// let auth = SessionAuthentication()
/// auth.accountIdentifier = "web_user"
/// auth.sessionId = "session_id_here"
/// auth.csrfToken = "csrf_token_here"
///
/// await auth.storeCookiesSettings()
/// ```
@MainActor
open class SessionAuthentication: Authentication {

    // MARK: - Configuration

    /// Whether to preserve device settings across sessions.
    public var keepDeviceSettings = true

    /// Identifies the cookie jar this session uses.
    ///
    /// Format: `"session-{20 random characters}"`.
    ///
    /// Changing it swaps in the storage for the new identifier. Callers
    /// restoring a saved account assign this before loading, and the old
    /// `lazy var cookieStorage` captured whichever identifier happened to be
    /// current at first access — so a restore that touched the storage first
    /// silently kept reading the wrong (freshly generated) jar.
    public var sessionIdentifier = "session-" + String.random(ofLength: 20) {
        didSet {
            guard oldValue != sessionIdentifier else { return }
            backingCookieStorage = nil
        }
    }

    // MARK: - Session Credentials

    /// The session ID identifying the authenticated user.
    public var sessionId: String?

    /// The CSRF token for security.
    public var csrfToken: String?

    // MARK: - Authorization Status

    /// Whether the authentication has a valid session.
    open var isAuthorized: Bool {
        if let currentSessionId = sessionId, !currentSessionId.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Cookie Storage

    /// Keychain category used for the cookie blob. Sits alongside the
    /// subclass's main `keychainCategory` so settings and cookies are
    /// independent items under the same account.
    private var cookiesKeychainCategory: String { "\(keychainCategory).cookies" }

    /// The HTTP cookie storage for this session.
    private var backingCookieStorage: HTTPCookieStorage?

    open var cookieStorage: HTTPCookieStorage {
        if let backingCookieStorage {
            return backingCookieStorage
        }

        let storage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sessionIdentifier)
        storage.cookieAcceptPolicy = .always
        backingCookieStorage = storage
        return storage
    }

    // MARK: - Persistence

    /// Deletes session credentials and cookies from the Keychain and memory.
    override open func delete() async {
        await super.delete()
        sessionId = nil
        csrfToken = nil
        await clearCookiesSettings()
    }

    // MARK: - Cookie Management

    /// Persists all current cookies to the Keychain.
    ///
    /// Cookies are encoded as a single property-list blob keyed by the
    /// account identifier and `cookiesKeychainCategory`. The blob is small
    /// enough for Keychain (a typical session jar is a few KB), so storing
    /// it whole keeps the migration simple and avoids fragmenting into
    /// one item per cookie.
    open func storeCookiesSettings() async {
        guard let account = accountIdentifier,
              let cookies = cookieStorage.cookies else { return }
        let category = cookiesKeychainCategory

        let codableCookies = cookies.compactMap { CodableHTTPCookie(from: $0) }

        do {
            let data = try PropertyListEncoder().encode(codableCookies)
            try await Task.detached {
                try KeychainStore.save(data, account: account, category: category)
            }.value
        } catch {
            Log.keychain.error("Failed to store session cookies in keychain: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Loads cookies from the Keychain and adds them to cookie storage.
    ///
    /// - Returns: The loaded cookies, or `nil` if none were stored.
    @discardableResult
    open func loadCookiesSettings() async -> [HTTPCookie]? {
        guard let account = accountIdentifier else { return nil }
        let category = cookiesKeychainCategory

        do {
            let data: Data? = try await Task.detached {
                try KeychainStore.load(account: account, category: category)
            }.value

            guard let data else { return nil }
            let codableCookies = try PropertyListDecoder().decode([CodableHTTPCookie].self, from: data)
            let cookies = codableCookies.compactMap { $0.httpCookie }

            cookies.forEach { cookie in
                cookieStorage.setCookie(cookie)
            }

            return cookies
        } catch {
            Log.keychain.error("Failed to load session cookies from keychain: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Removes the persisted cookies from the Keychain.
    public func clearCookiesSettings() async {
        guard let account = accountIdentifier else { return }
        let category = cookiesKeychainCategory

        await Task.detached {
            try? KeychainStore.delete(account: account, category: category)
        }.value
    }

    /// Clears all cookies from cookie storage.
    public func clearCookies() {
        cookieStorage.cookies?.forEach(cookieStorage.deleteCookie)
    }

    /// Sets cookies in cookie storage.
    ///
    /// - Parameter cookies: The cookies to set
    public func setCookies(_ cookies: [HTTPCookie]?) {
        cookies?.forEach {
            self.cookieStorage.setCookie($0)
        }
    }

    /// Retrieves all cookies from cookie storage.
    ///
    /// - Returns: An array of all stored cookies, or nil if none exist
    public func getCookies() -> [HTTPCookie]? {
        cookieStorage.cookies
    }
}

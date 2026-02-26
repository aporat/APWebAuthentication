import Foundation
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
    let isHTTPOnly: Bool

    /// Creates a codable cookie from an `HTTPCookie`.
    init?(from cookie: HTTPCookie) {
        self.name = cookie.name
        self.value = cookie.value
        self.domain = cookie.domain
        self.path = cookie.path
        self.expiresDate = cookie.expiresDate
        self.isSecure = cookie.isSecure
        self.isHTTPOnly = cookie.isHTTPOnly
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
        properties[.init(rawValue: "HttpOnly")] = isHTTPOnly

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

    /// Unique identifier for this session's cookie storage.
    ///
    /// Format: `"session-{20 random characters}"`
    public var sessionIdentifier = "session-" + String.random(ofLength: 20)

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

    /// The URL where cookies are stored on disk.
    ///
    /// Format: `account_{accountIdentifier}.cookies`
    private var cookiesURL: URL? {
        guard let currentAccountIdentifier = accountIdentifier,
              let documentsURL = FileManager.documentsDirectoryURL else {
            return nil
        }

        let fileName = "account_" + currentAccountIdentifier + ".cookies"
        return documentsURL.appendingPathComponent(fileName)
    }

    /// The HTTP cookie storage for this session.
    open lazy var cookieStorage: HTTPCookieStorage = {
        let storage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sessionIdentifier)
        storage.cookieAcceptPolicy = .always
        return storage
    }()

    // MARK: - Persistence

    /// Deletes session credentials from disk and memory.
    override open func delete() async {
        await super.delete()
        sessionId = nil
        csrfToken = nil
        await clearCookiesSettings()
    }

    // MARK: - Cookie Management

    /// Stores all current cookies to disk.
    open func storeCookiesSettings() async {
        guard let cookiesURL = cookiesURL, let cookies = cookieStorage.cookies else { return }

        let codableCookies = cookies.compactMap { CodableHTTPCookie(from: $0) }
        let encoder = PropertyListEncoder()

        do {
            let data = try encoder.encode(codableCookies)

            try await Task.detached {
                try data.write(to: cookiesURL)
            }.value
        } catch {
            log.error("⚠️ Failed to store cookies: \(error)")
        }
    }

    /// Loads cookies from disk and adds them to cookie storage.
    ///
    /// - Returns: The loaded cookies, or nil if loading fails
    @discardableResult
    open func loadCookiesSettings() async -> [HTTPCookie]? {
        guard let cookiesURL = cookiesURL else { return nil }

        do {
            let data = try await Task.detached {
                try Data(contentsOf: cookiesURL)
            }.value

            let decoder = PropertyListDecoder()
            let codableCookies = try decoder.decode([CodableHTTPCookie].self, from: data)
            let cookies = codableCookies.compactMap { $0.httpCookie }

            // Set cookies
            cookies.forEach { cookie in
                cookieStorage.setCookie(cookie)
            }

            return cookies
        } catch {
            log.error("⚠️ Failed to load cookies: \(error)")
        }

        return nil
    }

    /// Deletes the cookies file from disk.
    public func clearCookiesSettings() async {
        guard let cookiesURL = cookiesURL else { return }

        try? await Task.detached {
            try FileManager.default.removeItem(at: cookiesURL)
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

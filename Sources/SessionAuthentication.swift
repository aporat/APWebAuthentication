import Foundation
import SwifterSwift

// MARK: - Codable HTTPCookie

/// Internal wrapper for encoding and decoding `HTTPCookie` objects.
///
/// `HTTPCookie` doesn't conform to `Codable`, so this wrapper extracts
/// the essential properties for serialization to property lists.
private struct CodableHTTPCookie: Codable, Sendable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expiresDate: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool
    
    /// Creates a codable cookie from an `HTTPCookie`.
    ///
    /// - Parameter cookie: The HTTP cookie to wrap
    /// - Returns: A codable wrapper, or `nil` if required properties are missing
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
    ///
    /// - Returns: An `HTTPCookie` instance, or `nil` if conversion fails
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
/// `SessionAuthentication` manages web-style authentication that relies on:
/// - HTTP cookies for session persistence
/// - Session IDs for user identification
/// - CSRF tokens for security
/// - Cookie storage and retrieval
///
/// **Use Cases:**
/// - Web-based authentication flows
/// - Cookie-based session management
/// - APIs that use session cookies instead of bearer tokens
/// - Platforms with CSRF protection
///
/// **Example Usage:**
/// ```swift
/// let auth = SessionAuthentication()
/// auth.accountIdentifier = "web_user"
/// auth.sessionId = "session_id_here"
/// auth.csrfToken = "csrf_token_here"
///
/// // Store cookies
/// await auth.storeCookiesSettings()
///
/// // Later, load cookies
/// let cookies = await auth.loadCookiesSettings()
/// ```
///
/// **Platforms Using Session Auth:**
/// - Instagram Web
/// - Many web-based APIs
/// - Legacy authentication systems
///
/// - Note: All operations must be performed on the main actor.
@MainActor
open class SessionAuthentication: Authentication {
    
    // MARK: - Configuration
    
    /// Whether to preserve device settings across sessions.
    ///
    /// When `true`, device-specific settings (like fingerprints) are retained
    /// even after logout, making the app appear as the same device.
    ///
    /// **Example:**
    /// ```swift
    /// auth.keepDeviceSettings = true // Persist device identity
    /// ```
    public var keepDeviceSettings = true
    
    /// Unique identifier for this session's cookie storage.
    ///
    /// Automatically generated with a random suffix to isolate cookie storage
    /// between different accounts or sessions.
    ///
    /// **Format:** `"session-{20 random characters}"`
    public var sessionIdentifier = "session-" + String.random(ofLength: 20)
    
    // MARK: - Session Credentials
    
    /// The session ID identifying the authenticated user.
    ///
    /// This is typically stored in a cookie (e.g., `sessionid`) and sent with
    /// every request to maintain the authenticated session.
    ///
    /// **Example:**
    /// ```swift
    /// auth.sessionId = "abc123def456"
    /// ```
    public var sessionId: String?
    
    /// The CSRF (Cross-Site Request Forgery) token for security.
    ///
    /// Many web APIs require a CSRF token to prevent cross-site attacks.
    /// This token is sent with POST/PUT/DELETE requests.
    ///
    /// **Example:**
    /// ```swift
    /// auth.csrfToken = "csrf_token_value"
    /// // Send in header: X-CSRFToken: csrf_token_value
    /// ```
    public var csrfToken: String?
    
    // MARK: - Authorization Status
    
    /// Whether the authentication has a valid session.
    ///
    /// Returns `true` if a session ID is present and non-empty.
    /// Subclasses can override to add additional validation.
    ///
    /// **Example:**
    /// ```swift
    /// if auth.isAuthorized {
    ///     // Make authenticated requests
    ///     makeAPIRequest()
    /// } else {
    ///     // Show login screen
    ///     showLoginScreen()
    /// }
    /// ```
    ///
    /// - Returns: `true` if session ID is valid, `false` otherwise
    open var isAuthorized: Bool {
        if let currentSessionId = sessionId, !currentSessionId.isEmpty {
            return true
        }
        return false
    }
    
    // MARK: - Cookie Storage
    
    /// The URL where cookies are stored on disk.
    ///
    /// Automatically generated from the `accountIdentifier` and documents directory.
    /// Returns `nil` if no account identifier is set.
    ///
    /// **File Format:** `account_{accountIdentifier}.cookies`
    ///
    /// - Returns: URL to the cookies file, or `nil` if it cannot be determined
    private var cookiesURL: URL? {
        guard let currentAccountIdentifier = accountIdentifier,
              let documentsURL = FileManager.documentsDirectoryURL else {
            return nil
        }
        
        let fileName = "account_" + currentAccountIdentifier + ".cookies"
        return documentsURL.appendingPathComponent(fileName)
    }
    
    /// The HTTP cookie storage for this session.
    ///
    /// Uses a shared cookie storage container identified by `sessionIdentifier`.
    /// Cookies are automatically persisted and loaded by the system.
    ///
    /// **Configuration:**
    /// - Cookie accept policy: Always accept cookies
    /// - Container: Group container for isolation
    ///
    /// **Example:**
    /// ```swift
    /// let cookies = auth.cookieStorage.cookies
    /// print("Stored cookies: \(cookies?.count ?? 0)")
    /// ```
    lazy open var cookieStorage: HTTPCookieStorage = {
        let storage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sessionIdentifier)
        storage.cookieAcceptPolicy = .always
        return storage
    }()
    
    // MARK: - Settings Persistence
    
    /// Clears session credentials from disk and memory.
    ///
    /// This method:
    /// 1. Deletes the settings file (via super)
    /// 2. Clears the session ID
    /// 3. Clears the CSRF token
    /// 4. Deletes the cookies file
    ///
    /// **Example:**
    /// ```swift
    /// // Logout user
    /// await auth.clearAuthSettings()
    /// // auth.isAuthorized is now false
    /// // All cookies are removed from disk
    /// ```
    override open func clearAuthSettings() async {
        await super.clearAuthSettings()
        sessionId = nil
        csrfToken = nil
        await clearCookiesSettings()
    }
    
    // MARK: - Cookie Management
    
    /// Stores all current cookies to disk.
    ///
    /// Saves cookies from `cookieStorage` to a property list file.
    /// Only cookies are saved; session ID and CSRF token should be saved
    /// separately via subclass `storeAuthSettings()`.
    ///
    /// **Example:**
    /// ```swift
    /// // After login
    /// auth.setCookies(responseCookies)
    /// await auth.storeCookiesSettings()
    /// ```
    ///
    /// - Note: Errors are logged but not thrown
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
            print("⚠️ Failed to store cookies: \(error)")
        }
    }
    
    /// Loads cookies from disk and adds them to cookie storage.
    ///
    /// Reads cookies from the property list file and sets them in `cookieStorage`.
    ///
    /// **Example:**
    /// ```swift
    /// // On app launch
    /// let cookies = await auth.loadCookiesSettings()
    /// print("Loaded \(cookies?.count ?? 0) cookies")
    /// ```
    ///
    /// - Returns: The loaded cookies, or `nil` if loading fails
    /// - Note: Errors are logged but not thrown
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
            
            // Apply domain filter and set cookies
            cookies.forEach { cookie in
                cookieStorage.setCookie(cookie)
            }
            
            return cookies
        } catch {
            print("⚠️ Failed to load cookies: \(error)")
        }
        
        return nil
    }
    
    /// Deletes the cookies file from disk.
    ///
    /// Removes the property list file containing saved cookies.
    /// Does not affect cookies currently in memory (`cookieStorage`).
    ///
    /// **Example:**
    /// ```swift
    /// await auth.clearCookiesSettings() // Delete file
    /// auth.clearCookies() // Clear memory
    /// ```
    public func clearCookiesSettings() async {
        guard let cookiesURL = cookiesURL else { return }
        
        try? await Task.detached {
            try FileManager.default.removeItem(at: cookiesURL)
        }.value
    }
    
    /// Clears all cookies from cookie storage.
    ///
    /// Removes all cookies from memory but doesn't affect the cookies file on disk.
    /// Call `clearCookiesSettings()` to also delete the file.
    ///
    /// **Example:**
    /// ```swift
    /// auth.clearCookies() // Clear from memory
    /// await auth.clearCookiesSettings() // Delete from disk
    /// ```
    public func clearCookies() {
        cookieStorage.cookies?.forEach(cookieStorage.deleteCookie)
    }
    
    /// Sets cookies in cookie storage with domain filtering.
    ///
    /// Adds the provided cookies to `cookieStorage`
    ///
    /// **Example:**
    /// ```swift
    /// // From API response
    /// let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
    ///
    /// ```
    ///
    /// - Parameter cookies: The cookies to set, or `nil` to do nothing
    public func setCookies(_ cookies: [HTTPCookie]?) {
        cookies?.forEach {
            self.cookieStorage.setCookie($0)
        }
    }
    
    /// Retrieves all cookies from cookie storage.
    ///
    /// Returns all cookies currently stored in `cookieStorage`.
    ///
    /// **Example:**
    /// ```swift
    /// let cookies = auth.getCookies()
    /// print("Stored cookies:")
    /// cookies?.forEach { print("  \($0.name): \($0.value)") }
    /// ```
    ///
    /// - Returns: An array of all stored cookies, or `nil` if none exist
    public func getCookies() -> [HTTPCookie]? {
        cookieStorage.cookies
    }
}

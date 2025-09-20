import Foundation
import SwifterSwift

// 1. Create a Codable-compliant wrapper for HTTPCookie.
// This is necessary because the system's HTTPCookie class does not conform to Codable.
private struct CodableHTTPCookie: Codable {
    // Properties of HTTPCookie that we need to preserve
    let name: String
    let value: String
    let domain: String
    let path: String
    let expiresDate: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool
    
    // An initializer to convert a real HTTPCookie into our Codable wrapper
    init?(from cookie: HTTPCookie) {
        self.name = cookie.name
        self.value = cookie.value
        self.domain = cookie.domain
        self.path = cookie.path
        self.expiresDate = cookie.expiresDate
        self.isSecure = cookie.isSecure
        self.isHTTPOnly = cookie.isHTTPOnly
    }
    
    // A computed property to convert our wrapper back into a real HTTPCookie
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

open class SessionAuthentication: Authentication {
    public var keepDeviceSettings = true
    public var cookieSessionIdField = "session_id"
    public var sessionId: String?
    public var csrfToken: String?
    public var cookiesDomain = ""
    public var sessionIdentifier = "session-" + String.random(ofLength: 20)

    open var isAuthorized: Bool {
        if let currentSessionId = sessionId, !currentSessionId.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Auth Settings

    override open func clearAuthSettings() {
        super.clearAuthSettings()
        sessionId = nil
        csrfToken = nil
        clearCookiesSettings()
    }

    // MARK: - Cookies Settings

    fileprivate var cookiesURL: URL? {
        guard let currentAccountIdentifier = accountIdentifier else { return nil }
        return URL(fileURLWithPath: String.documentDirectory.appendingPathComponent("account_" + currentAccountIdentifier + ".cookies"))
    }

    lazy open var cookieStorage: HTTPCookieStorage = {
        let storage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sessionIdentifier)
        storage.cookieAcceptPolicy = .always
        return storage
    }()

    // 2. Refactored storeCookiesSettings to use the Codable wrapper and PropertyListEncoder.
    open func storeCookiesSettings() {
        if let cookiesURL = cookiesURL, let cookies = cookieStorage.cookies {
            // Convert the array of HTTPCookie objects to our Codable wrapper type
            let codableCookies = cookies.compactMap { CodableHTTPCookie(from: $0) }
            
            let encoder = PropertyListEncoder()
            do {
                let data = try encoder.encode(codableCookies)
                try data.write(to: cookiesURL)
            } catch {
                print("⚠️ Failed to store cookies settings: \(error)")
            }
        }
    }
    
    // 3. Refactored loadCookiesSettings to use PropertyListDecoder.
    @discardableResult
    open func loadCookiesSettings() -> [HTTPCookie]? {
        if let cookiesURL = cookiesURL,
           let data = try? Data(contentsOf: cookiesURL) {
            
            let decoder = PropertyListDecoder()
            do {
                // Decode the data into our array of Codable wrappers
                let codableCookies = try decoder.decode([CodableHTTPCookie].self, from: data)
                
                // Convert the wrappers back to real HTTPCookie objects
                let cookies = codableCookies.compactMap { $0.httpCookie }
                
                cookies.forEach { cookie in
                    if cookiesDomain.isEmpty || cookie.domain.hasSuffix(cookiesDomain) {
                        cookieStorage.setCookie(cookie)
                    }
                }
                return cookies
            } catch {
                print("⚠️ Failed to load cookies settings: \(error)")
            }
        }
        return nil
    }

    func clearCookiesSettings() {
        if let cookiesURL = cookiesURL {
            try? FileManager.default.removeItem(at: cookiesURL)
        }
    }

    public func clearCookies() {
        cookieStorage.cookies?.forEach(cookieStorage.deleteCookie)
    }

    public func setCookies(_ cookies: [HTTPCookie]?) {
        cookies?.forEach {
            if self.cookiesDomain.isEmpty || $0.domain.hasSuffix(self.cookiesDomain) {
                self.cookieStorage.setCookie($0)
            }
        }
    }

    public func getCookies() -> [HTTPCookie]? {
        cookieStorage.cookies
    }
}

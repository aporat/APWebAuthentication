import Foundation
import SwifterSwift

private struct CodableHTTPCookie: Codable, Sendable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expiresDate: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool
    
    init?(from cookie: HTTPCookie) {
        self.name = cookie.name
        self.value = cookie.value
        self.domain = cookie.domain
        self.path = cookie.path
        self.expiresDate = cookie.expiresDate
        self.isSecure = cookie.isSecure
        self.isHTTPOnly = cookie.isHTTPOnly
    }
    
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

@MainActor
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

    override open func clearAuthSettings() async {
        await super.clearAuthSettings()
        sessionId = nil
        csrfToken = nil
        await clearCookiesSettings()
    }

    // MARK: - Cookies Settings

    fileprivate var cookiesURL: URL? {
        guard let currentAccountIdentifier = accountIdentifier,
              let documentsURL = FileManager.documentsDirectoryURL else {
            return nil
        }
        
        let fileName = "account_" + currentAccountIdentifier + ".cookies"
        
        return documentsURL.appendingPathComponent(fileName)
    }

    lazy open var cookieStorage: HTTPCookieStorage = {
        let storage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sessionIdentifier)
        storage.cookieAcceptPolicy = .always
        return storage
    }()

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
            print("⚠️ Failed to store cookies settings: \(error)")
        }
    }
    
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
            
            cookies.forEach { cookie in
                if cookiesDomain.isEmpty || cookie.domain.hasSuffix(cookiesDomain) {
                    cookieStorage.setCookie(cookie)
                }
            }
            return cookies
        } catch {
            print("⚠️ Failed to load cookies settings: \(error)")
        }
        
        return nil
    }

    public func clearCookiesSettings() async {
        guard let cookiesURL = cookiesURL else { return }
        
        try? await Task.detached {
            try FileManager.default.removeItem(at: cookiesURL)
        }.value
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

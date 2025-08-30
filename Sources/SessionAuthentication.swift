import Foundation
import SwifterSwift

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

    open func storeCookiesSettings() {
        if let cookiesURL = cookiesURL, let cookies = cookieStorage.cookies {
            // Keep same archiving style (no secure coding requirement)
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: false) {
                try? data.write(to: cookiesURL)
            }
        }
    }

    @discardableResult
    open func loadCookiesSettings() -> [HTTPCookie]? {
        guard
            let cookiesURL = cookiesURL,
            let data = try? Data(contentsOf: cookiesURL)
        else {
            return nil
        }

        do {
            // Modern API: provide allowed classes (NSArray + HTTPCookie) and cast to [HTTPCookie]
            if let nsArray = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, HTTPCookie.self], from: data) as? [HTTPCookie] {
                nsArray.forEach {
                    if cookiesDomain.isEmpty || $0.domain.hasSuffix(cookiesDomain) {
                        cookieStorage.setCookie($0)
                    }
                }
                return nsArray
            }
        } catch {
            // Silently ignore (keeps prior behavior of try?)
            // You could log if desired
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

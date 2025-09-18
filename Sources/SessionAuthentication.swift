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
        if let cookiesURL = cookiesURL,
           let data = try? Data(contentsOf: cookiesURL) {

            let allowedClasses = [
                NSArray.self,
                HTTPCookie.self,
                NSDictionary.self,
                NSString.self,
                NSDate.self,
                NSNumber.self
            ]

            if let cookies = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: allowedClasses, from: data) as? [HTTPCookie] {
                cookies.forEach { cookie in
                    if cookiesDomain.isEmpty || cookie.domain.hasSuffix(cookiesDomain) {
                        cookieStorage.setCookie(cookie)
                    }
                }
                return cookies
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

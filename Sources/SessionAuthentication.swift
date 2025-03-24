import SwifterSwift
import UIKit

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
        guard let currentAccountIdentifier = accountIdentifier else {
            return nil
        }

        return URL(fileURLWithPath: String.documentDirectory.appendingPathComponent("account_" + currentAccountIdentifier + ".cookies"))
    }

    lazy open var cookieStorage: HTTPCookieStorage = {
        let storage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sessionIdentifier)
        storage.cookieAcceptPolicy = .always
        return storage
    }()

    open func storeCookiesSettings() {
        if let cookiesURL = cookiesURL, let cookies = cookieStorage.cookies {
            try? NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: false).write(to: cookiesURL)
        }
    }

    @discardableResult
    open func loadCookiesSettings() -> [HTTPCookie]? {
        if let cookiesURL = cookiesURL,
            let data = try? Data(contentsOf: cookiesURL),
            let cookies = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [HTTPCookie]
        {
            cookies.forEach {
                if cookiesDomain.isEmpty || $0.domain.hasSuffix(cookiesDomain) {
                    cookieStorage.setCookie($0)
                }
            }

            return cookies
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

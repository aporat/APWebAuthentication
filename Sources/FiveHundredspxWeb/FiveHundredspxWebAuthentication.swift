import Foundation

public final class FiveHundredspxWebAuthentication: SessionAuthentication {
    enum Keys {
        static let cookiesDomain = "cookies_domain"
        static let cookieSessionIdField = "cookie_session_id_field"
        static let browserMode = "browser_mode"
        static let customUserAgent = "custom_user_agent"
        static let sessionId = "session_id"
        static let csrfToken = "csrf_token"
    }

    public required init() {
        super.init()

        cookieSessionIdField = "x-500px-token"
        browserMode = .ios
    }

    public func loadAuthTokens(forceLoad: Bool = false) {
        if forceLoad || sessionId == nil || csrfToken == nil {
            cookieStorage.cookies?.forEach {
                if self.cookiesDomain.isEmpty || $0.domain.hasSuffix(self.cookiesDomain) {
                    if $0.name == "csrftoken", !$0.value.isEmpty {
                        self.csrfToken = $0.value
                    } else if $0.name == cookieSessionIdField, !$0.value.isEmpty {
                        self.sessionId = $0.value
                        self.csrfToken = $0.value
                    }
                }
            }
        }
    }

    override public var isAuthorized: Bool {
        if let sessionId = sessionId, !sessionId.isEmpty, let csrfToken = csrfToken, !csrfToken.isEmpty {
            return true
        }

        return false
    }

    // MARK: - Auth Settings

    override public func storeAuthSettings() {
        let deviceSettings: [String: Any?] = [
            Keys.cookiesDomain: cookiesDomain,
            Keys.browserMode: browserMode?.rawValue,
            Keys.customUserAgent: customUserAgent,

            Keys.cookieSessionIdField: cookieSessionIdField,
            Keys.sessionId: sessionId,
            Keys.csrfToken: csrfToken,
        ]

        if let authSettingsURL = authSettingsURL {
            try? NSKeyedArchiver.archivedData(withRootObject: deviceSettings, requiringSecureCoding: false).write(to: authSettingsURL)
        }

        storeCookiesSettings()
    }

    override public func loadAuthSettings() {
        if let authSettingsURL = authSettingsURL,
            let data = try? Data(contentsOf: authSettingsURL),
            let settings = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: Any?]
        {
            for (key, value) in settings {
                if key == Keys.cookiesDomain, let currentValue = value as? String {
                    cookiesDomain = currentValue
                } else if key == Keys.cookieSessionIdField, let currentValue = value as? String {
                    cookieSessionIdField = currentValue
                } else if key == Keys.browserMode, let currentValue = value as? String, let mode = ProviderBrowserMode(rawValue: currentValue) {
                    browserMode = mode
                } else if key == Keys.customUserAgent, let currentValue = value as? String {
                    customUserAgent = currentValue
                } else if key == Keys.sessionId, let currentValue = value as? String {
                    sessionId = currentValue
                } else if key == Keys.csrfToken, let currentValue = value as? String {
                    csrfToken = currentValue
                }
            }
        }

        loadCookiesSettings()
    }
}

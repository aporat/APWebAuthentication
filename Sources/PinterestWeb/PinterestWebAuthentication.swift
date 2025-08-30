import Foundation

public final class PinterestWebAuthentication: SessionAuthentication {
    enum Keys {
        static let cookiesDomain = "cookies_domain"
        static let cookieSessionIdField = "cookie_session_id_field"
        static let browserMode = "browser_mode"
        static let customUserAgent = "custom_user_agent"
        static let appId = "app_id"
        static let sessionId = "session_id"
        static let csrfToken = "csrf_token"
        static let username = "username"
    }

    var appId = "ad0e169"
    public var username: String?

    public required init() {
        super.init()

        cookieSessionIdField = "_pinterest_sess"
        browserMode = .desktopFirefox
    }

    public func loadAuthTokens(forceLoad: Bool = false) {
        if forceLoad || sessionId == nil || csrfToken == nil {
            cookieStorage.cookies?.forEach {
                if self.cookiesDomain.isEmpty || $0.domain.hasSuffix(self.cookiesDomain) {
                    if $0.name == "csrftoken", !$0.value.isEmpty {
                        self.csrfToken = $0.value
                    } else if $0.name == cookieSessionIdField, !$0.value.isEmpty {
                        self.sessionId = $0.value
                    }
                }
            }
        }
    }

    // MARK: - Auth Settings

    override public func storeAuthSettings() {
        let deviceSettings: [String: Any?] = [
            Keys.cookiesDomain: cookiesDomain,
            Keys.cookieSessionIdField: cookieSessionIdField,
            Keys.appId: appId,
            Keys.browserMode: browserMode?.rawValue,
            Keys.customUserAgent: customUserAgent,
            Keys.sessionId: sessionId,
            Keys.csrfToken: csrfToken,
            Keys.username: username,
        ]

        if let authSettingsURL = authSettingsURL {
            try? NSKeyedArchiver.archivedData(withRootObject: deviceSettings, requiringSecureCoding: false).write(to: authSettingsURL)
        }

        storeCookiesSettings()
    }

    override public func loadAuthSettings() {
        guard
            let authSettingsURL = authSettingsURL,
            let data = try? Data(contentsOf: authSettingsURL)
        else {
            loadCookiesSettings()
            return
        }

        do {
            if let settings = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSDictionary.self,
                from: data
            ) as? [String: Any?] {
                
                for (key, value) in settings {
                    switch key {
                    case Keys.cookiesDomain:       cookiesDomain       = value as? String ?? cookiesDomain
                    case Keys.cookieSessionIdField: cookieSessionIdField = value as? String ?? cookieSessionIdField
                    case Keys.appId:               appId               = value as? String ?? appId
                    case Keys.browserMode:
                        if let currentValue = value as? String,
                           let mode = ProviderBrowserMode(rawValue: currentValue) {
                            browserMode = mode
                        }
                    case Keys.customUserAgent:     customUserAgent     = value as? String
                    case Keys.sessionId:           sessionId           = value as? String
                    case Keys.csrfToken:           csrfToken           = value as? String
                    case Keys.username:            username            = value as? String
                    default: break
                    }
                }
            }
        } catch {
            print("⚠️ Failed to unarchive auth settings:", error)
        }

        loadCookiesSettings()
    }}

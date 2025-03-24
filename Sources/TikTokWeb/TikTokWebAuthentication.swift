import UIKit

public final class TikTokWebAuthentication: SessionAuthentication {
    enum Keys {
        static let signatureUrl = "signature_url"
        static let cookiesDomain = "cookies_domain"
        static let cookieSessionIdField = "cookie_session_id_field"
        static let browserMode = "browser_mode"
        static let customUserAgent = "custom_user_agent"
        static let sessionId = "session_id"
        static let svWebId = "s_v_web_id"
        static let sessionLastValidated = "session_last_validated"

        static let aid = "aid"
        static let screenWidth = "screen_width"
        static let screenHeight = "screen_height"
        static let browserLanguage = "browser_language"
        static let browserPlatform = "browser_platform"
        static let browserName = "browser_name"
        static let browserVersion = "browser_version"
        static let timezoneName = "timezone_name"
    }

    public var signatureUrl: URL?
    public var secUid: String?
    public var svWebId: String?
    public var ttWebId: String?
    public var uidtt: String?
    public var sessionLastValidated = Date().adding(.hour, value: -2)

    public var aid: String = "1988"
    public var screenWidth: String = "375"
    public var screenHeight: String = "812"
    public var browserLanguage: String = "en"
    public var browserPlatform: String = "MacIntel"
    public var browserName: String = "Mozilla"
    public var browserVersion: String = "5.0+(iPhone;+CPU+iPhone+OS+13_2_3+like+Mac+OS+X)+AppleWebKit/605.1.15+(KHTML,+like+Gecko)+Version/13.0.3+Mobile/15E148+Safari/604.1"
    public var timezoneName: String = "America/Chicago"

    public required init() {
        super.init()

        cookieSessionIdField = "sessionid"
    }

    override public var isAuthorized: Bool {
        if let currentSessionId = sessionId, !currentSessionId.isEmpty {
            return true
        }

        return false
    }

    public func loadAuthTokens(forceLoad: Bool = false) {
        if forceLoad || sessionId == nil || svWebId == nil {
            cookieStorage.cookies?.forEach {
                if self.cookiesDomain.isEmpty || $0.domain.hasSuffix(self.cookiesDomain) {
                    if $0.name == "s_v_web_id", !$0.value.isEmpty {
                        self.svWebId = $0.value
                    } else if $0.name == "tt_webid_v2", !$0.value.isEmpty {
                        self.ttWebId = $0.value
                    } else if $0.name == "uid_tt", !$0.value.isEmpty {
                        self.uidtt = $0.value
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
            Keys.signatureUrl: signatureUrl,
            Keys.cookiesDomain: cookiesDomain,
            Keys.cookieSessionIdField: cookieSessionIdField,
            Keys.browserMode: browserMode?.rawValue,
            Keys.customUserAgent: customUserAgent,
            Keys.sessionId: sessionId,
            Keys.svWebId: svWebId,
            Keys.sessionLastValidated: sessionLastValidated,
            Keys.aid: aid,
            Keys.screenWidth: screenWidth,
            Keys.screenHeight: screenHeight,
            Keys.browserLanguage: browserLanguage,
            Keys.browserPlatform: browserPlatform,
            Keys.browserName: browserName,
            Keys.browserVersion: browserVersion,
            Keys.timezoneName: timezoneName,
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
                if key == Keys.signatureUrl, let currentValue = value as? URL {
                    signatureUrl = currentValue
                } else if key == Keys.cookiesDomain, let currentValue = value as? String {
                    cookiesDomain = currentValue
                } else if key == Keys.cookieSessionIdField, let currentValue = value as? String {
                    cookieSessionIdField = currentValue
                } else if key == Keys.browserMode, let currentValue = value as? String, let mode = ProviderBrowserMode(rawValue: currentValue) {
                    browserMode = mode
                } else if key == Keys.customUserAgent, let currentValue = value as? String {
                    customUserAgent = currentValue
                }

                if key == Keys.sessionId, let currentValue = value as? String {
                    sessionId = currentValue
                } else if key == Keys.svWebId, let currentValue = value as? String {
                    svWebId = currentValue
                } else if key == Keys.sessionLastValidated, let currentValue = value as? Date {
                    sessionLastValidated = currentValue
                }

                if key == Keys.aid, let currentValue = value as? String {
                    aid = currentValue
                } else if key == Keys.screenWidth, let currentValue = value as? String {
                    screenWidth = currentValue
                } else if key == Keys.screenHeight, let currentValue = value as? String {
                    screenHeight = currentValue
                } else if key == Keys.browserLanguage, let currentValue = value as? String {
                    browserLanguage = currentValue
                } else if key == Keys.browserPlatform, let currentValue = value as? String {
                    browserPlatform = currentValue
                } else if key == Keys.browserName, let currentValue = value as? String {
                    browserName = currentValue
                } else if key == Keys.browserVersion, let currentValue = value as? String {
                    browserVersion = currentValue
                } else if key == Keys.timezoneName, let currentValue = value as? String {
                    timezoneName = currentValue
                }
            }
        }

        loadCookiesSettings()
    }
}

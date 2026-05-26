import Foundation
@preconcurrency import SwiftyJSON

@MainActor
public final class PinterestWebAuthentication: SessionAuthentication {

    private struct AuthSettings: Codable, Sendable {
        var browserMode: UserAgentMode?
        var customUserAgent: String?
        var appId: String?
        var sessionId: String?
        var csrfToken: String?
        var username: String?
    }

    var appId = "ad0e169"
    public var username: String?
  

    public func loadAuthTokens(forceLoad: Bool = false) {
        if forceLoad || sessionId == nil || csrfToken == nil {
            cookieStorage.cookies?.forEach {
                    if $0.name == "csrftoken", !$0.value.isEmpty {
                        self.csrfToken = $0.value
                    } else if $0.name == "_pinterest_sess", !$0.value.isEmpty {
                        self.sessionId = $0.value
                    }
            }
        }
    }

    // MARK: - Auth Settings

    override public var keychainCategory: String { "pinterest-web" }

    override public func save() async {
        let settings = AuthSettings(
            browserMode: browserMode,
            customUserAgent: customUserAgent,
            appId: appId,
            sessionId: sessionId,
            csrfToken: csrfToken,
            username: username
        )
        await saveSettings(settings)
        await storeCookiesSettings()
    }

    override public func load() async {
        if let settings = await loadSettings(AuthSettings.self) {
            browserMode = settings.browserMode ?? browserMode
            customUserAgent = settings.customUserAgent ?? customUserAgent
            appId = settings.appId ?? appId
            sessionId = settings.sessionId ?? sessionId
            csrfToken = settings.csrfToken ?? csrfToken
            username = settings.username ?? username
        }

        await loadCookiesSettings()
    }

    // MARK: - Configuration

    override public func configure(with options: JSON?) {
        super.configure(with: options)

        // Keep device settings flag
        if let value = options?["keep_device_settings"].bool {
            keepDeviceSettings = value
        }

        // App ID
        if let value = options?["app_id"].string {
            appId = value
        }
    }
}

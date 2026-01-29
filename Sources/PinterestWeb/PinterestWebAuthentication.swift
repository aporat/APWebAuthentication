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
        var isAuthenticated: Bool
    }
    
    var appId = "ad0e169"
    public var username: String?
    public var isAuthenticated: Bool = false
    
    override public var isAuthorized: Bool {
        return isAuthenticated
    }
    
    public func loadAuthTokens(forceLoad: Bool = false) {
        if forceLoad || sessionId == nil || csrfToken == nil {
            cookieStorage.cookies?.forEach {
                    if $0.name == "csrftoken", !$0.value.isEmpty {
                        self.csrfToken = $0.value
                    } else if $0.name == "_pinterest_sess", !$0.value.isEmpty {
                        self.sessionId = $0.value
                    } else if $0.name == "_auth", !$0.value.isEmpty {
                        self.isAuthenticated = $0.value == "1"
                    }
            }
        }
    }
    
    // MARK: - Auth Settings
    
    override public func save() async {
        let settings = AuthSettings(
            browserMode: browserMode,
            customUserAgent: customUserAgent,
            appId: appId,
            sessionId: sessionId,
            csrfToken: csrfToken,
            username: username,
            isAuthenticated: isAuthenticated
        )
        
        guard let authSettingsURL = authSettingsURL else { return }
        
        do {
            let data = try PropertyListEncoder().encode(settings)
            
            try await Task.detached {
                try data.write(to: authSettingsURL)
            }.value
        } catch {
            print("⚠️ Failed to store Pinterest settings: \(error)")
        }
        
        await storeCookiesSettings()
    }
    
    override public func load() async {
        guard let authSettingsURL = authSettingsURL else { return }
        
        do {
            let data = try await Task.detached {
                try Data(contentsOf: authSettingsURL)
            }.value
            
            let settings = try PropertyListDecoder().decode(AuthSettings.self, from: data)
            
            browserMode = settings.browserMode ?? browserMode
            customUserAgent = settings.customUserAgent ?? customUserAgent
            appId = settings.appId ?? appId
            sessionId = settings.sessionId ?? sessionId
            csrfToken = settings.csrfToken ?? csrfToken
            username = settings.username ?? username
            isAuthenticated = settings.isAuthenticated
            
        } catch {
            print("⚠️ Failed to load Pinterest settings: \(error)")
        }
        
        await loadCookiesSettings()
    }
    
    
    // MARK: - Configuration
    
    public override func configure(with options: JSON?) {
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

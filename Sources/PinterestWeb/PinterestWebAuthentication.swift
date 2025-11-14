import Foundation

@MainActor
public final class PinterestWebAuthentication: SessionAuthentication {
    
    private struct AuthSettings: Codable, Sendable {
        var cookiesDomain: String?
        var cookieSessionIdField: String?
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
    
    public required init() {
        super.init()
        
        cookieSessionIdField = "_pinterest_sess"
    }
    
    override public var isAuthorized: Bool {
        return isAuthenticated
    }
    
    public func loadAuthTokens(forceLoad: Bool = false) {
        if forceLoad || sessionId == nil || csrfToken == nil {
            cookieStorage.cookies?.forEach {
                if self.cookiesDomain.isEmpty || $0.domain.hasSuffix(self.cookiesDomain) {
                    if $0.name == "csrftoken", !$0.value.isEmpty {
                        self.csrfToken = $0.value
                    } else if $0.name == cookieSessionIdField, !$0.value.isEmpty {
                        self.sessionId = $0.value
                    } else if $0.name == "_auth", !$0.value.isEmpty {
                        self.isAuthenticated = $0.value == "1"
                    }
                }
            }
        }
    }
    
    // MARK: - Auth Settings
    
    override public func storeAuthSettings() async {
        let settings = AuthSettings(
            cookiesDomain: cookiesDomain,
            cookieSessionIdField: cookieSessionIdField,
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
    
    override public func loadAuthSettings() async {
        guard let authSettingsURL = authSettingsURL else { return }
        
        do {
            let data = try await Task.detached {
                try Data(contentsOf: authSettingsURL)
            }.value
            
            let settings = try PropertyListDecoder().decode(AuthSettings.self, from: data)
            
            cookiesDomain = settings.cookiesDomain ?? cookiesDomain
            cookieSessionIdField = settings.cookieSessionIdField ?? cookieSessionIdField
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
}

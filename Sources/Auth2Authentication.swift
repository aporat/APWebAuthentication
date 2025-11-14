import Foundation

@MainActor
public final class Auth2Authentication: Authentication {
    
    private struct AuthSettings: Codable, Sendable {
        let accessToken: String?
        let refreshToken: String?
        let clientId: String?
    }
    
    public var clientId: String?
    public var accessToken: String?
    public var refreshToken: String?
    
    public required init() {}
    
    func setBrowserMode(_ mode: UserAgentMode) {
        self.browserMode = mode
    }
    
    func setCustomUserAgent(_ agent: String) {
        self.customUserAgent = agent
    }
    
    public var isAuthorized: Bool {
        if let currentAccessToken = accessToken, !currentAccessToken.isEmpty {
            return true
        }
        return false
    }
    
    // MARK: - Auth Settings
    
    override public func storeAuthSettings() async {
        let settings = AuthSettings(
            accessToken: self.accessToken,
            refreshToken: self.refreshToken,
            clientId: self.clientId
        )
        
        guard let authSettingsURL = authSettingsURL else { return }
        
        do {
            let data = try PropertyListEncoder().encode(settings)
            
            try await Task.detached {
                try data.write(to: authSettingsURL)
            }.value
        } catch {
            print("⚠️ Failed to store Auth2 settings: \(error)")
        }
    }
    
    override public func loadAuthSettings() async {
        guard let authSettingsURL = authSettingsURL else { return }
        
        do {
            let data = try await Task.detached {
                try Data(contentsOf: authSettingsURL)
            }.value
            
            let settings = try PropertyListDecoder().decode(AuthSettings.self, from: data)
            self.accessToken = settings.accessToken
            self.refreshToken = settings.refreshToken
            self.clientId = settings.clientId
        } catch {
            print("⚠️ Failed to load Auth2 settings: \(error)")
        }
    }
    
    override public func clearAuthSettings() async {
        await super.clearAuthSettings()
        accessToken = nil
        refreshToken = nil
        clientId = nil
    }
}

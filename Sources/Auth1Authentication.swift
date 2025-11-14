import Foundation

@MainActor
public final class Auth1Authentication: Authentication {
    
    private struct AuthSettings: Codable, Sendable {
        let token: String?
        let secret: String?
    }
    
    public var token: String?
    public var secret: String?
    
    public required init() {}
    
    public var isAuthorized: Bool {
        if let currentToken = token,
           let currentSecret = secret,
           !currentToken.isEmpty,
           !currentSecret.isEmpty {
            return true
        }
        return false
    }
    
    func setBrowserMode(_ mode: UserAgentMode) {
        self.browserMode = mode
    }
    
    func setCustomUserAgent(_ agent: String) {
        self.customUserAgent = agent
    }
    
    // MARK: - Auth Settings
    
    override public func storeAuthSettings() async {
        let settings = AuthSettings(token: token, secret: secret)
        guard let authSettingsURL = authSettingsURL else { return }
        
        do {
            let data = try PropertyListEncoder().encode(settings)
            
            try await Task.detached {
                try data.write(to: authSettingsURL)
            }.value
        } catch {
            print("⚠️ Failed to store Auth1 settings: \(error)")
        }
    }
    
    override public func loadAuthSettings() async {
        guard let authSettingsURL = authSettingsURL else { return }
        
        do {
            let data = try await Task.detached {
                try Data(contentsOf: authSettingsURL)
            }.value
            
            let settings = try PropertyListDecoder().decode(AuthSettings.self, from: data)
            self.token = settings.token
            self.secret = settings.secret
        } catch {
            print("⚠️ Failed to load Auth1 settings: \(error)")
        }
    }
    
    override public func clearAuthSettings() async {
        await super.clearAuthSettings()
        token = nil
        secret = nil
    }
}

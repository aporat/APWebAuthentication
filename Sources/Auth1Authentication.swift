import Foundation

public final class Auth1Authentication: Authentication {
    private struct AuthSettings: Codable {
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

    // MARK: - Auth Settings

    override public func storeAuthSettings() {
            let settings = AuthSettings(token: token, secret: secret)

            if let authSettingsURL = authSettingsURL {
                let encoder = PropertyListEncoder()
                do {
                    let data = try encoder.encode(settings)
                    try data.write(to: authSettingsURL)
                } catch {
                    print("⚠️ Failed to store Auth1 settings: \(error)")
                }
            }
        }

    override public func loadAuthSettings() {
        if let authSettingsURL = authSettingsURL,
           let data = try? Data(contentsOf: authSettingsURL) {
            
            let decoder = PropertyListDecoder()
            do {
                let settings = try decoder.decode(AuthSettings.self, from: data)
                self.token = settings.token
                self.secret = settings.secret
            } catch {
                print("⚠️ Failed to load Auth1 settings: \(error)")
            }
        }
    }

    override public func clearAuthSettings() {
        super.clearAuthSettings()
        token = nil
        secret = nil
    }
}

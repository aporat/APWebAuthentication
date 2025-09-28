import Foundation

public final class Auth2Authentication: Authentication, Sendable {
    
    private struct AuthSettings: Codable {
        let accessToken: String?
        let clientId: String?
    }

    public var clientId: String?
    public var accessToken: String?

    public required init() {}

    public var isAuthorized: Bool {
        if let currentAccessToken = accessToken, !currentAccessToken.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Auth Settings

    override public func storeAuthSettings() {
        let settings = AuthSettings(
            accessToken: self.accessToken,
            clientId: self.clientId
        )

        if let authSettingsURL = authSettingsURL {
            let encoder = PropertyListEncoder()
            do {
                let data = try encoder.encode(settings)
                try data.write(to: authSettingsURL)
            } catch {
                print("⚠️ Failed to store Auth2 settings: \(error)")
            }
        }
    }

    override public func loadAuthSettings() {
        if let authSettingsURL = authSettingsURL,
           let data = try? Data(contentsOf: authSettingsURL) {
            
            let decoder = PropertyListDecoder()
            do {
                // Decode the data directly into the settings struct
                let settings = try decoder.decode(AuthSettings.self, from: data)
                self.accessToken = settings.accessToken
                self.clientId = settings.clientId
            } catch {
                print("⚠️ Failed to load Auth2 settings: \(error)")
            }
        }
    }

    override public func clearAuthSettings() {
        super.clearAuthSettings()
        accessToken = nil
        clientId = nil
    }
}

import Foundation

public final class Auth2Authentication: Authentication {
    enum Keys {
        static let accessToken = "access_token"
        static let clientId = "client_id"
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
        let deviceSettings: [String: Any?] = [
            Keys.accessToken: accessToken,
            Keys.clientId: clientId,
        ]

        if let authSettingsURL = authSettingsURL {
            do {
                let data = try NSKeyedArchiver.archivedData(
                    withRootObject: deviceSettings,
                    requiringSecureCoding: false
                )
                try data.write(to: authSettingsURL)
            } catch {
                print("⚠️ Failed to store Auth2 settings: \(error)")
            }
        }
    }

    override public func loadAuthSettings() {
        if let authSettingsURL = authSettingsURL,
           let data = try? Data(contentsOf: authSettingsURL) {

            let allowedClasses = [
                NSDictionary.self,
                NSString.self
            ]

            if let settings = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: allowedClasses, from: data) as? [String: Any?] {
                
                for (key, value) in settings {
                    switch key {
                    case Keys.accessToken: accessToken = (value as? String) ?? accessToken
                    case Keys.clientId:    clientId = (value as? String) ?? clientId
                    default:
                        break
                    }
                }
            }
        }
    }

    override public func clearAuthSettings() {
        super.clearAuthSettings()
        accessToken = nil
        clientId = nil
    }
}

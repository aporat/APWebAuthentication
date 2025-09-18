import Foundation

public final class Auth1Authentication: Authentication {
    enum Keys {
        static let token = "token"
        static let secret = "secret"
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
        let settings: [String: Any?] = [
            Keys.token: token,
            Keys.secret: secret,
        ]

        if let authSettingsURL = authSettingsURL {
            do {
                let data = try NSKeyedArchiver.archivedData(
                    withRootObject: settings,
                    requiringSecureCoding: false
                )
                try data.write(to: authSettingsURL)
            } catch {
                print("⚠️ Failed to store Auth1 settings: \(error)")
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
                    case Keys.token:  token = (value as? String) ?? token
                    case Keys.secret: secret = (value as? String) ?? secret
                    default:
                        break
                    }
                }
            }
        }
    }

    override public func clearAuthSettings() {
        super.clearAuthSettings()
        token = nil
        secret = nil
    }
}

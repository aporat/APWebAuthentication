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
        if let currentToken = token, let currentSecret = secret, !currentToken.isEmpty, !currentSecret.isEmpty {
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
            try? NSKeyedArchiver.archivedData(withRootObject: settings, requiringSecureCoding: false).write(to: authSettingsURL)
        }
    }

    override public func loadAuthSettings() {
        if let authSettingsURL = authSettingsURL,
            let data = try? Data(contentsOf: authSettingsURL),
            let settings = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: Any?]
        {
            for (key, value) in settings {
                if key == Keys.token, let currentValue = value as? String {
                    token = currentValue
                } else if key == Keys.secret, let currentValue = value as? String {
                    secret = currentValue
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

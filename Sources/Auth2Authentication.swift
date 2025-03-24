import UIKit

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
            try? NSKeyedArchiver.archivedData(withRootObject: deviceSettings, requiringSecureCoding: false).write(to: authSettingsURL)
        }
    }

    override public func loadAuthSettings() {
        if let authSettingsURL = authSettingsURL,
            let data = try? Data(contentsOf: authSettingsURL),
            let settings = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: Any?]
        {
            for (key, value) in settings {
                if key == Keys.accessToken, let currentValue = value as? String {
                    accessToken = currentValue
                } else if key == Keys.clientId, let currentValue = value as? String {
                    clientId = currentValue
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

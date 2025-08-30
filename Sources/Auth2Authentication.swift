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
        guard
            let authSettingsURL = authSettingsURL,
            let data = try? Data(contentsOf: authSettingsURL)
        else { return }

        do {
            if let settings = try NSKeyedUnarchiver
                .unarchivedObject(ofClass: NSDictionary.self, from: data) as? [String: Any?] {

                for (key, value) in settings {
                    switch key {
                    case Keys.accessToken:
                        if let v = value as? String { accessToken = v }
                    case Keys.clientId:
                        if let v = value as? String { clientId = v }
                    default: break
                    }
                }
            }
        } catch {
            print("⚠️ Failed to load Auth2 settings: \(error)")
        }
    }

    override public func clearAuthSettings() {
        super.clearAuthSettings()
        accessToken = nil
        clientId = nil
    }
}

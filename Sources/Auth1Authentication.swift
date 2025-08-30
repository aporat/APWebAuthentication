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
        guard
            let authSettingsURL = authSettingsURL,
            let data = try? Data(contentsOf: authSettingsURL)
        else { return }

        do {
            if let settings = try NSKeyedUnarchiver
                .unarchivedObject(ofClass: NSDictionary.self, from: data) as? [String: Any?] {

                for (key, value) in settings {
                    switch key {
                    case Keys.token:
                        if let v = value as? String { token = v }
                    case Keys.secret:
                        if let v = value as? String { secret = v }
                    default: break
                    }
                }
            }
        } catch {
            print("⚠️ Failed to load Auth1 settings: \(error)")
        }
    }

    override public func clearAuthSettings() {
        super.clearAuthSettings()
        token = nil
        secret = nil
    }
}

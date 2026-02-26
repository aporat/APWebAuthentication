import Foundation

/// OAuth 1.0a authentication manager.
///
/// Manages OAuth 1.0a credentials including access token, access token secret,
/// and persistent storage.
///
/// **Example Usage:**
/// ```swift
/// let auth = Auth1Authentication()
/// auth.accountIdentifier = "twitter_user"
/// auth.token = "user_token"
/// auth.secret = "user_secret"
///
/// if auth.isAuthorized {
///     await auth.save()
/// }
/// ```
@MainActor
public final class Auth1Authentication: Authentication {

    // MARK: - Settings Storage

    /// Internal structure for encoding/decoding OAuth 1.0a settings.
    private struct AuthSettings: Codable, Sendable {
        let token: String?
        let secret: String?
    }

    // MARK: - OAuth 1.0a Credentials

    /// The OAuth access token.
    public var token: String?

    /// The OAuth access token secret.
    public var secret: String?

    // MARK: - Initialization

    /// Creates a new OAuth 1.0a authentication instance.
    public required init() {}

    // MARK: - Authorization Status

    /// Whether the authentication has valid credentials.
    public var isAuthorized: Bool {
        if let currentToken = token,
           let currentSecret = secret,
           !currentToken.isEmpty,
           !currentSecret.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Configuration

    /// Sets the browser mode for user agent generation.
    func setBrowserMode(_ mode: UserAgentMode) {
        self.browserMode = mode
    }

    /// Sets a custom user agent string.
    func setCustomUserAgent(_ agent: String) {
        self.customUserAgent = agent
    }

    // MARK: - Persistence

    /// Saves OAuth 1.0a credentials to disk.
    override public func save() async {
        let settings = AuthSettings(token: token, secret: secret)
        guard let authSettingsURL = authSettingsURL else { return }

        do {
            let data = try PropertyListEncoder().encode(settings)

            try await Task.detached {
                try data.write(to: authSettingsURL)
            }.value
        } catch {
            print("⚠️ Failed to store OAuth 1.0a settings: \(error)")
        }
    }

    /// Loads OAuth 1.0a credentials from disk.
    override public func load() async {
        guard let authSettingsURL = authSettingsURL else { return }

        do {
            let data = try await Task.detached {
                try Data(contentsOf: authSettingsURL)
            }.value

            let settings = try PropertyListDecoder().decode(AuthSettings.self, from: data)
            self.token = settings.token
            self.secret = settings.secret
        } catch {
            print("⚠️ Failed to load OAuth 1.0a settings: \(error)")
        }
    }

    /// Deletes OAuth 1.0a credentials from disk and memory.
    override public func delete() async {
        await super.delete()
        token = nil
        secret = nil
    }
}

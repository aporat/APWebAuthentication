import Foundation

/// OAuth 1.0a authentication manager.
///
/// Manages OAuth 1.0a credentials including access token, access token secret,
/// and persistent storage.
///
/// **Example Usage:**
/// ```swift
/// let auth = Auth1Authentication()
/// auth.accountIdentifier = "x_user"
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
        let consumerKey: String?
        let consumerSecret: String?
    }

    // MARK: - OAuth 1.0a Credentials

    /// The OAuth access token.
    public var token: String?

    /// The OAuth access token secret.
    public var secret: String?

    /// The OAuth consumer key.
    public var consumerKey: String?

    /// The OAuth consumer secret.
    public var consumerSecret: String?

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

    // MARK: - Persistence

    override public var keychainCategory: String { "oauth1" }

    /// Saves OAuth 1.0a credentials to the Keychain.
    override public func save() async {
        let settings = AuthSettings(token: token, secret: secret, consumerKey: consumerKey, consumerSecret: consumerSecret)
        await saveSettings(settings)
    }

    /// Loads OAuth 1.0a credentials from the Keychain.
    override public func load() async {
        guard let settings = await loadSettings(AuthSettings.self) else { return }
        self.token = settings.token
        self.secret = settings.secret
        self.consumerKey = settings.consumerKey
        self.consumerSecret = settings.consumerSecret
    }

    /// Deletes OAuth 1.0a credentials from disk and memory.
    override public func delete() async {
        await super.delete()
        token = nil
        secret = nil
        consumerKey = nil
        consumerSecret = nil
    }
}

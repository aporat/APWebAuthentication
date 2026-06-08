import Foundation
@preconcurrency import SwiftyJSON

/// OAuth 2.0 authentication manager.
///
/// Manages OAuth 2.0 credentials including access token, refresh token, client ID,
/// and persistent storage.
///
/// **Example Usage:**
/// ```swift
/// let auth = Auth2Authentication()
/// auth.accountIdentifier = "reddit_user"
/// auth.clientId = "app_client_id"
/// auth.accessToken = "access_token_here"
/// auth.refreshToken = "refresh_token_here"
///
/// if auth.isAuthorized {
///     await auth.save()
/// }
/// ```
@MainActor
open class Auth2Authentication: Authentication {

    // MARK: - Settings Storage

    /// Internal structure for encoding/decoding OAuth 2.0 settings.
    private struct AuthSettings: Codable, Sendable {
        let accessToken: String?
        let refreshToken: String?
        let clientId: String?
        let clientSecret: String?
    }

    // MARK: - OAuth 2.0 Credentials

    /// The OAuth client ID.
    public var clientId: String?

    /// The OAuth client secret.
    public var clientSecret: String?

    /// The OAuth access token.
    public var accessToken: String?

    /// The OAuth refresh token.
    public var refreshToken: String?

    // MARK: - Initialization

    /// Creates a new OAuth 2.0 authentication instance.
    public required init() {}

    // MARK: - Authorization Status

    /// Whether the authentication has a valid access token.
    open var isAuthorized: Bool {
        if let currentAccessToken = accessToken, !currentAccessToken.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Persistence

    override open var keychainCategory: String { "oauth2" }

    /// Saves OAuth 2.0 credentials to the Keychain.
    override open func save() async {
        let settings = AuthSettings(
            accessToken: self.accessToken,
            refreshToken: self.refreshToken,
            clientId: self.clientId,
            clientSecret: self.clientSecret
        )
        await saveSettings(settings)
    }

    /// Loads OAuth 2.0 credentials from the Keychain.
    override open func load() async {
        guard let settings = await loadSettings(AuthSettings.self) else { return }
        self.accessToken = settings.accessToken
        self.refreshToken = settings.refreshToken
        self.clientId = settings.clientId
        self.clientSecret = settings.clientSecret
    }

    /// Deletes OAuth 2.0 credentials from disk and memory.
    override open func delete() async {
        await super.delete()
        accessToken = nil
        refreshToken = nil
        clientId = nil
        clientSecret = nil
    }

    // MARK: - Runtime Configuration

    override open func configure(with options: JSON?) {
        super.configure(with: options)

        if let value = options?["client_id"].string {
            clientId = value
        }

        if let value = options?["client_secret"].string {
            clientSecret = value
        }
    }
}

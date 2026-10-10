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
    ///
    /// Every field is optional, so blobs written by older versions (before
    /// `expiresAt` existed) still decode — the synthesized decoder uses
    /// `decodeIfPresent` for optionals.
    struct AuthSettings: Codable, Sendable {
        let accessToken: String?
        let refreshToken: String?
        let clientId: String?
        let clientSecret: String?
        let expiresAt: Date?
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

    /// When the access token expires, from the token response's `expires_in`.
    ///
    /// `nil` means unknown (the server sent no `expires_in`, or the token was
    /// stored by a version that did not record it); `OAuth2Interceptor` then
    /// relies on the 401 retry path alone. When you store a token yourself,
    /// set this too — ``applyTokenResponse(_:now:)`` does it for you.
    public var expiresAt: Date?

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

    /// Whether the access token has expired or will within `leeway` seconds.
    /// Always `false` when ``expiresAt`` is unknown.
    public func isAccessTokenExpiring(within leeway: TimeInterval, now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSince(now) <= leeway
    }

    // MARK: - Token Updates

    /// Sets ``expiresAt`` from a token response's `expires_in` (seconds).
    /// A missing or invalid value clears it — an old expiry would no longer
    /// describe the new token.
    public func setExpiration(expiresIn: TimeInterval?, now: Date = Date()) {
        if let expiresIn, expiresIn.isFinite, expiresIn >= 0 {
            expiresAt = now.addingTimeInterval(expiresIn)
        } else {
            expiresAt = nil
        }
    }

    /// Stores the tokens from an OAuth 2.0 token endpoint response — or from
    /// an implicit-flow callback, via `JSON(callbackURL.parameters)`.
    ///
    /// Reads `access_token`, `refresh_token` (kept when absent, since servers
    /// that do not rotate refresh tokens omit it) and `expires_in` (a number or
    /// a numeric string). Does not persist; call ``save()`` afterwards.
    ///
    /// - Returns: `false`, changing nothing, when there is no access token.
    @discardableResult
    public func applyTokenResponse(_ json: JSON, now: Date = Date()) -> Bool {
        guard let token = json["access_token"].string, !token.isEmpty else { return false }
        accessToken = token
        if let refreshed = json["refresh_token"].string, !refreshed.isEmpty {
            refreshToken = refreshed
        }
        setExpiration(expiresIn: Self.seconds(from: json["expires_in"]), now: now)
        return true
    }

    /// `expires_in` as seconds, accepting a JSON number or a numeric string.
    static func seconds(from json: JSON) -> TimeInterval? {
        if let number = json.number {
            return number.doubleValue
        }
        if let string = json.string {
            return TimeInterval(string.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    // MARK: - Persistence

    override open var keychainCategory: String { "oauth2" }

    /// Saves OAuth 2.0 credentials to the Keychain.
    override open func save() async {
        await saveSettings(persistedSettings)
    }

    /// Loads OAuth 2.0 credentials from the Keychain.
    override open func load() async {
        guard let settings = await loadSettings(AuthSettings.self) else { return }
        restore(from: settings)
    }

    /// The persisted form of the credentials.
    var persistedSettings: AuthSettings {
        AuthSettings(
            accessToken: accessToken,
            refreshToken: refreshToken,
            clientId: clientId,
            clientSecret: clientSecret,
            expiresAt: expiresAt
        )
    }

    /// Restores credentials from their persisted form.
    func restore(from settings: AuthSettings) {
        accessToken = settings.accessToken
        refreshToken = settings.refreshToken
        clientId = settings.clientId
        clientSecret = settings.clientSecret
        expiresAt = settings.expiresAt
    }

    /// Deletes OAuth 2.0 credentials from disk and memory.
    override open func delete() async {
        await super.delete()
        accessToken = nil
        refreshToken = nil
        clientId = nil
        clientSecret = nil
        expiresAt = nil
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

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
public final class Auth2Authentication: Authentication {

    // MARK: - Settings Storage

    /// Internal structure for encoding/decoding OAuth 2.0 settings.
    private struct AuthSettings: Codable, Sendable {
        let accessToken: String?
        let refreshToken: String?
        let clientId: String?
    }

    // MARK: - OAuth 2.0 Credentials

    /// The OAuth client ID.
    public var clientId: String?

    /// The OAuth access token.
    public var accessToken: String?

    /// The OAuth refresh token.
    public var refreshToken: String?

    // MARK: - Initialization

    /// Creates a new OAuth 2.0 authentication instance.
    public required init() {}

    // MARK: - Configuration

    /// Sets the browser mode for user agent generation.
    func setBrowserMode(_ mode: UserAgentMode) {
        self.browserMode = mode
    }

    /// Sets a custom user agent string.
    func setCustomUserAgent(_ agent: String) {
        self.customUserAgent = agent
    }

    // MARK: - Authorization Status

    /// Whether the authentication has a valid access token.
    public var isAuthorized: Bool {
        if let currentAccessToken = accessToken, !currentAccessToken.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Persistence

    /// Saves OAuth 2.0 credentials to disk.
    override public func save() async {
        let settings = AuthSettings(
            accessToken: self.accessToken,
            refreshToken: self.refreshToken,
            clientId: self.clientId
        )

        guard let authSettingsURL = authSettingsURL else { return }

        do {
            let data = try PropertyListEncoder().encode(settings)

            try await Task.detached {
                try data.write(to: authSettingsURL)
            }.value
        } catch {
            print("⚠️ Failed to store OAuth 2.0 settings: \(error)")
        }
    }

    /// Loads OAuth 2.0 credentials from disk.
    override public func load() async {
        guard let authSettingsURL = authSettingsURL else { return }

        do {
            let data = try await Task.detached {
                try Data(contentsOf: authSettingsURL)
            }.value

            let settings = try PropertyListDecoder().decode(AuthSettings.self, from: data)
            self.accessToken = settings.accessToken
            self.refreshToken = settings.refreshToken
            self.clientId = settings.clientId
        } catch {
            print("⚠️ Failed to load OAuth 2.0 settings: \(error)")
        }
    }

    /// Deletes OAuth 2.0 credentials from disk and memory.
    override public func delete() async {
        await super.delete()
        accessToken = nil
        refreshToken = nil
        clientId = nil
    }

    // MARK: - Runtime Configuration

    override public func configure(with options: JSON?) {
        super.configure(with: options)

        if let value = options?["client_id"].string {
            clientId = value
        }
    }
}

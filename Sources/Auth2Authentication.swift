import Foundation
@preconcurrency import SwiftyJSON

/// OAuth 2.0 authentication manager.
///
/// `Auth2Authentication` manages OAuth 2.0 credentials including:
/// - Access token (identifies the user and authorizes requests)
/// - Refresh token (obtains new access tokens when expired)
/// - Client ID (identifies the application)
/// - Persistent storage of credentials
/// - Authorization status checking
///
/// **OAuth 2.0 Overview:**
/// OAuth 2.0 uses bearer tokens for authentication. Each request includes:
/// ```
/// Authorization: Bearer {access_token}
/// ```
///
/// When the access token expires, the refresh token can be used to obtain
/// a new access token without requiring the user to log in again.
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
///
/// **Platforms Using OAuth 2.0:**
/// - Reddit
/// - GitHub
/// - Pinterest
/// - Twitch
/// - Most modern APIs
///
/// - Note: All operations must be performed on the main actor.
@MainActor
public final class Auth2Authentication: Authentication {

    // MARK: - Settings Storage

    /// Internal structure for encoding/decoding OAuth 2.0 settings.
    ///
    /// This structure is used for property list serialization of credentials.
    private struct AuthSettings: Codable, Sendable {
        let accessToken: String?
        let refreshToken: String?
        let clientId: String?
    }

    // MARK: - OAuth 2.0 Credentials

    /// The OAuth client ID.
    ///
    /// This identifies your application to the OAuth provider.
    /// Typically obtained when registering your app with the platform.
    ///
    /// **Example:**
    /// ```swift
    /// auth.clientId = "abc123def456"
    /// ```
    public var clientId: String?

    /// The OAuth access token.
    ///
    /// This token is sent with every authenticated request as a Bearer token.
    /// It has a limited lifetime and should be refreshed when expired.
    ///
    /// **Example:**
    /// ```swift
    /// auth.accessToken = "ya29.a0AfH6SMBx..."
    /// // Use in requests:
    /// // Authorization: Bearer ya29.a0AfH6SMBx...
    /// ```
    public var accessToken: String?

    /// The OAuth refresh token.
    ///
    /// This token is used to obtain new access tokens when they expire,
    /// without requiring the user to re-authenticate.
    ///
    /// **Example:**
    /// ```swift
    /// auth.refreshToken = "1//0gLTCK..."
    /// // Use to get new access token when expired
    /// ```
    ///
    /// - Note: Not all OAuth flows provide refresh tokens (implicit flow doesn't)
    public var refreshToken: String?

    // MARK: - Initialization

    /// Creates a new OAuth 2.0 authentication instance.
    public required init() {}

    // MARK: - Configuration

    /// Sets the browser mode for user agent generation.
    ///
    /// - Parameter mode: The desired browser/device mode
    func setBrowserMode(_ mode: UserAgentMode) {
        self.browserMode = mode
    }

    /// Sets a custom user agent string.
    ///
    /// When set, this overrides automatic user agent generation.
    ///
    /// - Parameter agent: The custom user agent string
    func setCustomUserAgent(_ agent: String) {
        self.customUserAgent = agent
    }

    // MARK: - Authorization Status

    /// Whether the authentication has a valid access token.
    ///
    /// Returns `true` if an access token is present and non-empty.
    /// This indicates the user has completed OAuth authorization.
    ///
    /// **Example:**
    /// ```swift
    /// if auth.isAuthorized {
    ///     // Make authenticated API requests
    ///     let client = OAuth2Client(auth: auth)
    /// } else {
    ///     // Show login screen
    ///     showLoginScreen()
    /// }
    /// ```
    ///
    /// - Note: This doesn't check if the token is expired; it only verifies presence
    ///
    /// - Returns: `true` if access token is valid, `false` otherwise
    public var isAuthorized: Bool {
        if let currentAccessToken = accessToken, !currentAccessToken.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Persistence

    /// Saves OAuth 2.0 credentials to disk.
    ///
    /// Saves the access token, refresh token, and client ID to a property list file
    /// in the documents directory. The file name is based on the `accountIdentifier`.
    ///
    /// **File Format:** Property list containing access token, refresh token, and client ID
    ///
    /// **Example:**
    /// ```swift
    /// auth.accessToken = "access_token"
    /// auth.refreshToken = "refresh_token"
    /// auth.clientId = "client_id"
    /// await auth.save()
    /// ```
    ///
    /// - Note: Errors are logged but not thrown to avoid interrupting the flow
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
    ///
    /// Reads the access token, refresh token, and client ID from the property list
    /// file and updates the corresponding properties.
    ///
    /// **Example:**
    /// ```swift
    /// await auth.load()
    /// if auth.isAuthorized {
    ///     print("Credentials loaded successfully")
    ///     print("Access token: \(auth.accessToken ?? "none")")
    /// }
    /// ```
    ///
    /// - Note: Errors are logged but not thrown; properties remain nil on failure
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
    ///
    /// This method:
    /// 1. Deletes the settings file (via super)
    /// 2. Clears the access token property
    /// 3. Clears the refresh token property
    /// 4. Clears the client ID property
    ///
    /// **Example:**
    /// ```swift
    /// // Logout user
    /// await auth.delete()
    /// // auth.isAuthorized is now false
    /// ```
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

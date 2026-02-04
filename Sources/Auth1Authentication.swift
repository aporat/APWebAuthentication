import Foundation

/// OAuth 1.0a authentication manager.
///
/// `Auth1Authentication` manages OAuth 1.0a credentials including:
/// - Access token (identifies the user)
/// - Access token secret (signs requests)
/// - Persistent storage of credentials
/// - Authorization status checking
///
/// **OAuth 1.0a Overview:**
/// OAuth 1.0a uses a token + secret pair to sign requests with HMAC-SHA1.
/// Both the token and secret are required for authenticated requests.
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
///
/// **Platforms Using OAuth 1.0a:**
/// - Twitter/X
/// - Tumblr
/// - Some legacy APIs
///
/// - Note: All operations must be performed on the main actor.
@MainActor
public final class Auth1Authentication: Authentication {

    // MARK: - Settings Storage

    /// Internal structure for encoding/decoding OAuth 1.0a settings.
    ///
    /// This structure is used for property list serialization of credentials.
    private struct AuthSettings: Codable, Sendable {
        let token: String?
        let secret: String?
    }

    // MARK: - OAuth 1.0a Credentials

    /// The OAuth access token.
    ///
    /// This token identifies the user and is sent with every authenticated request.
    /// Combined with the `secret`, it forms the complete OAuth 1.0a credential.
    ///
    /// **Example:**
    /// ```swift
    /// auth.token = "1234567890-abcdefghijklmnop"
    /// ```
    public var token: String?

    /// The OAuth access token secret.
    ///
    /// This secret is used to sign requests along with the consumer secret.
    /// It should be kept secure and never transmitted in plain text.
    ///
    /// **Example:**
    /// ```swift
    /// auth.secret = "secret_key_here"
    /// ```
    public var secret: String?

    // MARK: - Initialization

    /// Creates a new OAuth 1.0a authentication instance.
    public required init() {}

    // MARK: - Authorization Status

    /// Whether the authentication has valid credentials.
    ///
    /// Returns `true` only if both token and secret are present and non-empty.
    /// This indicates the user has completed OAuth authorization.
    ///
    /// **Example:**
    /// ```swift
    /// if auth.isAuthorized {
    ///     // Make authenticated API requests
    ///     let client = OAuth1Client(auth: auth)
    /// } else {
    ///     // Show login screen
    ///     showLoginScreen()
    /// }
    /// ```
    ///
    /// - Returns: `true` if both token and secret are valid, `false` otherwise
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

    // MARK: - Persistence

    /// Saves OAuth 1.0a credentials to disk.
    ///
    /// Saves the token and secret to a property list file in the documents directory.
    /// The file name is based on the `accountIdentifier`.
    ///
    /// **File Format:** Property list containing token and secret
    ///
    /// **Example:**
    /// ```swift
    /// auth.token = "user_token"
    /// auth.secret = "user_secret"
    /// await auth.save()
    /// ```
    ///
    /// - Note: Errors are logged but not thrown to avoid interrupting the flow
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
    ///
    /// Reads the token and secret from the property list file and updates
    /// the `token` and `secret` properties.
    ///
    /// **Example:**
    /// ```swift
    /// await auth.load()
    /// if auth.isAuthorized {
    ///     print("Credentials loaded successfully")
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
            self.token = settings.token
            self.secret = settings.secret
        } catch {
            print("⚠️ Failed to load OAuth 1.0a settings: \(error)")
        }
    }

    /// Deletes OAuth 1.0a credentials from disk and memory.
    ///
    /// This method:
    /// 1. Deletes the settings file (via super)
    /// 2. Clears the token property
    /// 3. Clears the secret property
    ///
    /// **Example:**
    /// ```swift
    /// // Logout user
    /// await auth.delete()
    /// // auth.isAuthorized is now false
    /// ```
    override public func delete() async {
        await super.delete()
        token = nil
        secret = nil
    }
}

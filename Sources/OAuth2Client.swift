import Alamofire
import Foundation

/// HTTP client for OAuth 2.0 authenticated APIs.
///
/// `OAuth2Client` extends `AuthClient` to provide OAuth 2.0 authentication support.
/// It handles:
/// - OAuth 2.0 bearer token authentication
/// - Automatic token refresh (if implemented in interceptor)
/// - User agent and browser mode configuration
///
/// **OAuth 2.0 Flow:**
/// OAuth 2.0 uses bearer tokens for authentication. Each request includes:
/// ```
/// Authorization: Bearer <access_token>
/// ```
///
/// The client supports multiple OAuth 2.0 grant types through its authentication object:
/// - Authorization Code
/// - Client Credentials
/// - Refresh Token
///
/// **Example:**
/// ```swift
/// let auth = Auth2Authentication(
///     accessToken: "user_access_token",
///     refreshToken: "refresh_token",
///     clientId: "your_client_id",
///     clientSecret: "your_client_secret"
/// )
///
/// let client = OAuth2Client(
///     baseURLString: "https://api.example.com/v1/",
///     auth: auth
/// )
///
/// let json = try await client.request("/me")
/// ```
///
/// - Note: OAuth 2.0 is used by platforms like Reddit, GitHub, Pinterest, and many modern APIs.
@MainActor
open class OAuth2Client: AuthClient {

    // MARK: - Properties

    /// The OAuth 2.0 request interceptor handling bearer token injection.
    ///
    /// This interceptor adds the `Authorization: Bearer` header to each request
    /// and may handle automatic token refresh if configured.
    public var interceptor: OAuth2Interceptor

    /// Creates a new OAuth 2.0 client with a custom request interceptor.
    ///
    /// Use this initializer when you need to provide a custom OAuth2Interceptor
    /// subclass with specialized behavior.
    ///
    /// **Example:**
    /// ```swift
    /// class CustomOAuth2Interceptor: OAuth2Interceptor {
    ///     // Custom token refresh logic
    /// }
    ///
    /// let interceptor = CustomOAuth2Interceptor(auth: auth)
    /// let client = OAuth2Client(
    ///     accountType: AccountStore.myPlatform,
    ///     baseURLString: "https://api.example.com/",
    ///     requestInterceptor: interceptor
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - accountType: The account type/platform this client targets
    ///   - baseURLString: The base URL for all API requests
    ///   - requestInterceptor: The request interceptor (must be OAuth2Interceptor or subclass)
    ///
    /// - Important: The interceptor must be an OAuth2Interceptor or subclass, otherwise initialization will fail with a precondition.
    public init(accountType: AccountType, baseURLString: String, requestInterceptor: OAuth2Interceptor) {
        self.interceptor = requestInterceptor
        super.init(accountType: accountType, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }

}

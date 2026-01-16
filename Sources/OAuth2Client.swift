import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

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
    
    // MARK: - Initialization
    
    /// Creates a new OAuth 2.0 client with the specified authentication.
    ///
    /// This convenience initializer creates an OAuth2Interceptor automatically
    /// from the provided authentication object.
    ///
    /// - Parameters:
    ///   - baseURLString: The base URL for all API requests
    ///   - auth: The authentication object containing access/refresh tokens
    public convenience init(baseURLString: String, auth: Auth2Authentication) {
        let interceptor = OAuth2Interceptor(auth: auth)
        self.init(baseURLString: baseURLString, requestInterceptor: interceptor)
    }
    
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
    ///     baseURLString: "https://api.example.com/",
    ///     requestInterceptor: interceptor
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - baseURLString: The base URL for all API requests
    ///   - requestInterceptor: The request interceptor (must be OAuth2Interceptor or subclass)
    ///
    /// - Important: The interceptor must be an OAuth2Interceptor or subclass, otherwise a fatal error occurs.
    public override init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        // Validate interceptor type
        guard let customInterceptor = requestInterceptor as? OAuth2Interceptor else {
            fatalError("OAuth2Client requires an OAuth2Interceptor (or subclass).")
        }
        
        self.interceptor = customInterceptor
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
    
    // MARK: - Configuration
    
    /// Loads configuration settings from a JSON options object.
    ///
    /// This method updates the authentication configuration based on provided options.
    /// Supported options:
    /// - `browser_mode`: Sets the user agent mode (mobile, desktop, or custom)
    /// - `custom_user_agent`: Sets a custom user agent string
    ///
    /// **Example:**
    /// ```swift
    /// let options: JSON = [
    ///     "browser_mode": "desktop",
    ///     "custom_user_agent": "MyApp/2.0 (iPhone; iOS 17.0)"
    /// ]
    /// await client.loadSettings(options)
    /// ```
    ///
    /// - Parameter options: JSON object containing configuration key-value pairs
    public func loadSettings(_ options: JSON?) async {
        // Update browser mode
        if let value = UserAgentMode(options?["browser_mode"].string) {
            interceptor.auth.setBrowserMode(value)
        }
        
        // Update custom user agent
        if let value = options?["custom_user_agent"].string {
            interceptor.auth.setCustomUserAgent(value)
        }
    }
}

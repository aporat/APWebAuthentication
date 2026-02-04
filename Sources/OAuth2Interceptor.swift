import Alamofire
import Foundation

// MARK: - Token Location

/// Specifies where the OAuth 2.0 access token should be included in requests.
public enum TokenLocation: Int, Sendable {

    /// Include the token in the Authorization header (recommended).
    ///
    /// **Format:** `Authorization: Bearer {access_token}`
    ///
    /// This is the recommended approach per RFC 6750 (OAuth 2.0 Bearer Token Usage).
    case authorizationHeader

    /// Include the token as a query/form parameter.
    ///
    /// **Format:** `?access_token={access_token}`
    ///
    /// This is less secure but may be required by some APIs.
    case params
}

// MARK: - OAuth 2.0 Interceptor

/// Request interceptor that adds OAuth 2.0 bearer token authentication to HTTP requests.
///
/// `OAuth2Interceptor` implements OAuth 2.0 bearer token authentication by:
/// - Adding the access token to requests (header or parameter)
/// - Adding user agent and Accept headers
/// - Supporting different token locations (header vs parameter)
///
/// **OAuth 2.0 Bearer Token:**
/// OAuth 2.0 uses bearer tokens for authentication. The token is typically sent in
/// the Authorization header:
/// ```
/// Authorization: Bearer {access_token}
/// ```
///
/// Alternatively, some APIs accept the token as a query or form parameter:
/// ```
/// https://api.example.com/users?access_token={access_token}
/// ```
///
/// **Example Usage:**
/// ```swift
/// let auth = Auth2Authentication()
/// auth.accessToken = "user_access_token"
///
/// let interceptor = OAuth2Interceptor(auth: auth)
/// interceptor.tokenLocation = .authorizationHeader // Recommended
///
/// let client = OAuth2Client(
///     baseURLString: "https://api.example.com/",
///     auth: auth
/// )
/// ```
///
/// **Configuration Options:**
/// - `tokenLocation`: Where to send the token (header or params)
/// - `tokenParamName`: Parameter name when using params location
/// - `tokenHeaderParamName`: Authorization scheme name (usually "Bearer")
///
/// **Platforms Using OAuth 2.0:**
/// - Reddit
/// - GitHub
/// - Pinterest
/// - Twitch
/// - Most modern APIs
///

public class OAuth2Interceptor: RequestInterceptor, @unchecked Sendable {

    // MARK: - Configuration

    /// The parameter name when sending the token as a query/form parameter.
    ///
    /// Used when `tokenLocation` is set to `.params`.
    ///
    /// **Default:** `"access_token"`
    ///
    /// **Example:**
    /// ```swift
    /// interceptor.tokenParamName = "token"
    /// // Results in: ?token={access_token}
    /// ```
    let tokenParamName: String

    /// The authorization scheme name when sending the token in the header.
    ///
    /// Used when `tokenLocation` is set to `.authorizationHeader`.
    ///
    /// **Default:** `"Bearer"`
    ///
    /// **Example:**
    /// ```swift
    /// interceptor.tokenHeaderParamName = "Bearer"
    /// // Results in: Authorization: Bearer {access_token}
    /// ```
    let tokenHeaderParamName: String

    /// Specifies where the access token should be included in requests.
    ///
    /// **Options:**
    /// - `.authorizationHeader` - In Authorization header (recommended, RFC 6750)
    /// - `.params` - As query/form parameter (less secure)
    ///
    /// **Default:** `.params` (for compatibility with legacy APIs)
    ///
    /// **Example:**
    /// ```swift
    /// // Recommended approach
    /// interceptor.tokenLocation = .authorizationHeader
    /// // Authorization: Bearer {token}
    ///
    /// // Alternative for APIs that require params
    /// interceptor.tokenLocation = .params
    /// // ?access_token={token}
    /// ```
    let tokenLocation: TokenLocation

    /// The authentication manager containing the access token.
    ///
    /// Provides access to the user's OAuth 2.0 access token.
    ///
    /// - Note: Marked `nonisolated(unsafe)` because it's immutable after initialization
    ///         and MainActor-isolated properties are accessed safely within Task contexts.
    let auth: Auth2Authentication

    // MARK: - Initialization

    /// Creates a new OAuth 2.0 request interceptor.
    ///
    /// **Example:**
    /// ```swift
    /// let auth = Auth2Authentication()
    /// auth.accessToken = "access_token"
    ///
    /// let interceptor = OAuth2Interceptor(auth: auth)
    ///
    /// // Or with custom configuration:
    /// let interceptor = OAuth2Interceptor(
    ///     auth: auth,
    ///     tokenLocation: .authorizationHeader,
    ///     tokenParamName: "token",
    ///     tokenHeaderParamName: "Bearer"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - auth: The authentication manager with access token
    ///   - tokenLocation: Where to include the token (default: `.params`)
    ///   - tokenParamName: Parameter name for token (default: `"access_token"`)
    ///   - tokenHeaderParamName: Authorization scheme name (default: `"Bearer"`)
    public init(
        auth: Auth2Authentication,
        tokenLocation: TokenLocation = .params,
        tokenParamName: String = "access_token",
        tokenHeaderParamName: String = "Bearer"
    ) {
        self.auth = auth
        self.tokenLocation = tokenLocation
        self.tokenParamName = tokenParamName
        self.tokenHeaderParamName = tokenHeaderParamName
    }

    // MARK: - RequestAdapter

    /// Adapts requests by adding OAuth 2.0 bearer token authentication.
    ///
    /// This method:
    /// 1. Gets the access token from the authentication manager
    /// 2. Adds the user agent if available
    /// 3. Adds the access token based on `tokenLocation`:
    ///    - Header: `Authorization: Bearer {token}`
    ///    - Params: `?access_token={token}` (or custom param name)
    /// 4. Adds Accept header for JSON responses
    ///
    /// **Authorization Header (Recommended):**
    /// ```
    /// Authorization: Bearer ya29.a0AfH6SMBx...
    /// ```
    ///
    /// **Query Parameter (Alternative):**
    /// ```
    /// https://api.example.com/users?access_token=ya29.a0AfH6SMBx...
    /// ```
    ///
    /// - Parameters:
    ///   - urlRequest: The request to adapt
    ///   - session: The Alamofire session
    ///   - completion: Completion handler with adapted request or error
    public func adapt(
        _ urlRequest: URLRequest,
        for _: Session,
        completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
    ) {
        Task {
            var urlRequest = urlRequest

            // Add user agent if available
            if let currentUserAgent = await auth.userAgent, !currentUserAgent.isEmpty {
                urlRequest.headers.add(.userAgent(currentUserAgent))
            }

            // Get access token
            let currentAccessToken = await auth.accessToken

            // Add token to Authorization header (recommended)
            if let currentAccessToken, !currentAccessToken.isEmpty, tokenLocation == .authorizationHeader {
                urlRequest.headers.add(.authorization("\(tokenHeaderParamName) \(currentAccessToken)"))
            }

            // Add Accept header
            urlRequest.headers.add(.accept("application/json"))

            // Add token as parameter (alternative)
            if let currentAccessToken, !currentAccessToken.isEmpty, tokenLocation == .params {
                let params: Parameters = [tokenParamName: currentAccessToken]

                do {
                    let encodedRequest = try URLEncoding.default.encode(urlRequest, with: params)
                    completion(.success(encodedRequest))
                } catch {
                    completion(.failure(error))
                }
                return
            }

            completion(.success(urlRequest))
        }
    }
}

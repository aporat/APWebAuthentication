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

    /// The URL for the OAuth 2.0 token refresh endpoint.
    ///
    /// When set, the interceptor will automatically attempt to refresh the access token
    /// using the refresh token grant when a 401 Unauthorized response is received.
    ///
    /// **Example:**
    /// ```swift
    /// interceptor.refreshTokenURL = "https://api.tumblr.com/v2/oauth2/token"
    /// ```
    ///
    /// - Note: Requires `auth.refreshToken`, `auth.clientId`, and `auth.clientSecret` to be set.
    let refreshTokenURL: String?

    // MARK: - Refresh Token State

    /// Whether a token refresh is currently in progress.
    private var isRefreshing = false

    /// Queued retry completions waiting for the token refresh to finish.
    private var requestsToRetry: [(RetryResult) -> Void] = []

    /// Lock for thread-safe access to refresh state.
    private let lock = NSLock()

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
    ///
    /// // With refresh token support:
    /// let interceptor = OAuth2Interceptor(
    ///     auth: auth,
    ///     tokenLocation: .authorizationHeader,
    ///     refreshTokenURL: "https://api.example.com/oauth2/token"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - auth: The authentication manager with access token
    ///   - tokenLocation: Where to include the token (default: `.params`)
    ///   - tokenParamName: Parameter name for token (default: `"access_token"`)
    ///   - tokenHeaderParamName: Authorization scheme name (default: `"Bearer"`)
    ///   - refreshTokenURL: The token endpoint URL for refresh grants (default: `nil`, disabling auto-refresh)
    public init(
        auth: Auth2Authentication,
        tokenLocation: TokenLocation = .params,
        tokenParamName: String = "access_token",
        tokenHeaderParamName: String = "Bearer",
        refreshTokenURL: String? = nil
    ) {
        self.auth = auth
        self.tokenLocation = tokenLocation
        self.tokenParamName = tokenParamName
        self.tokenHeaderParamName = tokenHeaderParamName
        self.refreshTokenURL = refreshTokenURL
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

    // MARK: - RequestRetrier

    /// Retries failed requests by refreshing the access token when a 401 is received.
    ///
    /// This method:
    /// 1. Checks if the failure is a 401 and refresh is configured
    /// 2. Queues the retry completion if a refresh is already in progress
    /// 3. Calls the token endpoint with the refresh token grant
    /// 4. Updates the auth credentials and retries all queued requests on success
    /// 5. Fails all queued requests if the refresh fails
    ///
    /// Only one refresh attempt is made per request (`retryCount == 0`) to prevent infinite loops.
    ///
    /// - Parameters:
    ///   - request: The failed Alamofire request
    ///   - session: The Alamofire session
    ///   - error: The error that caused the failure
    ///   - completion: Completion handler with retry decision
    public func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping @Sendable (RetryResult) -> Void
    ) {
        // Only retry once per request to prevent loops
        guard request.retryCount == 0,
              let refreshTokenURL,
              let response = request.task?.response as? HTTPURLResponse,
              response.statusCode == 401 else {
            completion(.doNotRetry)
            return
        }

        lock.lock()
        requestsToRetry.append(completion)

        guard !isRefreshing else {
            lock.unlock()
            return
        }

        isRefreshing = true
        lock.unlock()

        Task { @MainActor in
            let succeeded = await self.refreshAccessToken(url: refreshTokenURL)

            let completions = self.lock.withLock {
                let completions = self.requestsToRetry
                self.requestsToRetry.removeAll()
                self.isRefreshing = false
                return completions
            }

            completions.forEach { $0(succeeded ? .retry : .doNotRetry) }
        }
    }

    // MARK: - Token Refresh

    /// Calls the OAuth 2.0 token endpoint with the refresh token grant.
    ///
    /// Sends a POST request with:
    /// - `grant_type=refresh_token`
    /// - `client_id`
    /// - `client_secret`
    /// - `refresh_token`
    ///
    /// On success, updates `auth.accessToken` and `auth.refreshToken` and persists them.
    ///
    /// - Parameter url: The token endpoint URL
    /// - Returns: `true` if the token was refreshed successfully, `false` otherwise
    @MainActor
    private func refreshAccessToken(url: String) async -> Bool {
        guard let refreshToken = auth.refreshToken,
              let clientId = auth.clientId,
              let clientSecret = auth.clientSecret else {
            return false
        }

        let parameters: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken
        ]

        do {
            let response = await AF.request(
                url,
                method: .post,
                parameters: parameters,
                encoder: URLEncodedFormParameterEncoder.default
            )
            .validate()
            .serializingDecodable(TokenResponse.self)
            .response

            guard let tokenResponse = response.value else {
                auth.accessToken = nil
                auth.refreshToken = nil
                await auth.save()
                return false
            }

            auth.accessToken = tokenResponse.accessToken
            if let newRefreshToken = tokenResponse.refreshToken {
                auth.refreshToken = newRefreshToken
            }
            await auth.save()

            return true
        }
    }
}

// MARK: - Token Response

/// Response from an OAuth 2.0 token endpoint.
private struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

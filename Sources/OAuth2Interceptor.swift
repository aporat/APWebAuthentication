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

// MARK: - Client Authentication

/// How the client proves its identity to the token endpoint during a
/// refresh-token grant (RFC 6749 §2.3.1).
///
/// In every mode, a `nil` `clientSecret` on the auth object means the app is
/// a **public client** (e.g. a PKCE flow): only `client_id` is sent and no
/// secret is required. Providers differ on where a *confidential* client's
/// secret goes:
///
/// | Provider | Mode |
/// |---|---|
/// | Tumblr | `.requestBody` — `client_secret` as a form field |
/// | X (Twitter) | `.basicAuthorizationHeader` — `Authorization: Basic base64(id:secret)` |
public enum OAuth2ClientAuthentication: Sendable {

    /// Send `client_id` and `client_secret` as form fields in the body.
    case requestBody

    /// Send `client_id:client_secret` as an HTTP Basic `Authorization`
    /// header. `client_id` is still included in the body, which the RFC
    /// permits and X requires.
    case basicAuthorizationHeader
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
    /// Provides access to the user's OAuth 2.0 access token. `Auth2Authentication`
    /// is `@MainActor`-isolated, so reads are performed from a MainActor-bound
    /// `Task` in `adapt` / `retry`.
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
    /// - Note: Requires `auth.refreshToken` and `auth.clientId`. `auth.clientSecret`
    ///         is optional — see ``OAuth2ClientAuthentication``.
    let refreshTokenURL: String?

    /// How the client authenticates to the token endpoint during refresh.
    let clientAuthentication: OAuth2ClientAuthentication

    /// Session used for the refresh request itself. Kept separate from the
    /// API session so a refresh is never intercepted by this interceptor
    /// (which would recurse on a 401 from the token endpoint).
    let refreshSession: Session

    // MARK: - Refresh Token State

    /// Whether a token refresh is currently in progress.
    private var isRefreshing = false

    /// Queued retry completions waiting for the token refresh to finish.
    private var requestsToRetry: [(RetryResult) -> Void] = []

    /// IDs of requests that have already been granted one refresh. A request
    /// that 401s again after its refresh is failed rather than refreshed a
    /// second time, which is what prevents an endless refresh loop. Kept as
    /// a small FIFO because Alamofire offers no hook to learn when a retried
    /// request finally completes.
    private var refreshedRequestIDs: [UUID] = []
    private static let refreshedRequestIDsLimit = 64

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
    ///   - clientAuthentication: Where a confidential client's secret goes during refresh (default: `.requestBody`)
    ///   - refreshSession: Session used for the refresh request (default: `AF`)
    public init(
        auth: Auth2Authentication,
        tokenLocation: TokenLocation = .params,
        tokenParamName: String = "access_token",
        tokenHeaderParamName: String = "Bearer",
        refreshTokenURL: String? = nil,
        clientAuthentication: OAuth2ClientAuthentication = .requestBody,
        refreshSession: Session = AF
    ) {
        self.auth = auth
        self.tokenLocation = tokenLocation
        self.tokenParamName = tokenParamName
        self.tokenHeaderParamName = tokenHeaderParamName
        self.refreshTokenURL = refreshTokenURL
        self.clientAuthentication = clientAuthentication
        self.refreshSession = refreshSession
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
        // Hop to MainActor once instead of awaiting each `auth` property
        // independently — `Auth2Authentication` is MainActor-isolated.
        Task { @MainActor in
            var urlRequest = urlRequest

            // Add user agent if available
            if let currentUserAgent = auth.userAgent, !currentUserAgent.isEmpty {
                urlRequest.headers.add(.userAgent(currentUserAgent))
            }

            // Get access token
            let currentAccessToken = auth.accessToken

            // Add token to Authorization header (recommended)
            if let currentAccessToken, !currentAccessToken.isEmpty, tokenLocation == .authorizationHeader {
                urlRequest.headers.add(.authorization("\(tokenHeaderParamName) \(currentAccessToken)"))
            }

            // Add Accept header
            urlRequest.headers.add(.accept("application/json"))

            // Add token as parameter (alternative)
            if let currentAccessToken, !currentAccessToken.isEmpty, tokenLocation == .params {
                let params: Parameters = [tokenParamName: currentAccessToken]

                // Always append to the query string. `URLEncoding.default`
                // would move the token into the body for POST/PUT/PATCH and
                // overwrite whatever body the caller already encoded.
                do {
                    let encodedRequest = try URLEncoding.queryString.encode(urlRequest, with: params)
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
    /// Only one refresh attempt is made per request to prevent infinite loops.
    /// The check is per request rather than on `retryCount`, so a 401 that
    /// arrives after `TransientNetworkRetrier` has already retried the request
    /// (e.g. 503 → retry → 401) still triggers a refresh.
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
        guard let refreshTokenURL,
              let response = request.task?.response as? HTTPURLResponse,
              response.statusCode == 401 else {
            completion(.doNotRetry)
            return
        }

        // Atomically: refuse a second refresh for the same request, enqueue
        // the completion, and decide whether we're the request that kicks
        // off the refresh. Holding the lock across all three steps prevents
        // another request from observing `isRefreshing` before we've claimed it.
        //
        // `nil`  → this request already had its one refresh; fail it.
        // `true` → we start the refresh; `false` → one is already in flight.
        let shouldStartRefresh: Bool? = lock.withLock {
            if let index = refreshedRequestIDs.firstIndex(of: request.id) {
                refreshedRequestIDs.remove(at: index)
                return nil
            }
            refreshedRequestIDs.append(request.id)
            if refreshedRequestIDs.count > Self.refreshedRequestIDsLimit {
                refreshedRequestIDs.removeFirst()
            }

            requestsToRetry.append(completion)
            guard !isRefreshing else { return false }
            isRefreshing = true
            return true
        }

        guard let shouldStartRefresh else {
            completion(.doNotRetry)
            return
        }
        guard shouldStartRefresh else { return }

        Task { @MainActor in
            let succeeded = await self.refreshAccessToken(url: refreshTokenURL)

            let completions: [(RetryResult) -> Void] = self.lock.withLock {
                let drained = self.requestsToRetry
                self.requestsToRetry.removeAll()
                self.isRefreshing = false
                return drained
            }

            completions.forEach { $0(succeeded ? .retry : .doNotRetry) }
        }
    }

    // MARK: - Token Refresh

    /// Calls the OAuth 2.0 token endpoint with the refresh token grant.
    ///
    /// Sends a form-encoded POST with `grant_type=refresh_token`,
    /// `refresh_token` and `client_id`. A confidential client's secret is
    /// added according to ``clientAuthentication``; a public client (no
    /// secret configured) sends nothing else.
    ///
    /// On success, updates `auth.accessToken` and `auth.refreshToken` and persists them.
    ///
    /// - Parameter url: The token endpoint URL
    /// - Returns: `true` if the token was refreshed successfully, `false` otherwise
    @MainActor
    func refreshAccessToken(url: String) async -> Bool {
        guard let refreshToken = auth.refreshToken,
              let clientId = auth.clientId else {
            return false
        }

        var parameters: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": clientId,
            "refresh_token": refreshToken
        ]
        var headers: HTTPHeaders = [.contentType("application/x-www-form-urlencoded")]

        if let clientSecret = auth.clientSecret, !clientSecret.isEmpty {
            switch clientAuthentication {
            case .requestBody:
                parameters["client_secret"] = clientSecret
            case .basicAuthorizationHeader:
                headers.add(.authorization(username: clientId, password: clientSecret))
            }
        }

        let response = await refreshSession.request(
            url,
            method: .post,
            parameters: parameters,
            encoder: URLEncodedFormParameterEncoder.default,
            headers: headers
        )
        .validate()
        .serializingDecodable(TokenResponse.self)
        .response

        if let tokenResponse = response.value {
            auth.accessToken = tokenResponse.accessToken
            if let newRefreshToken = tokenResponse.refreshToken {
                auth.refreshToken = newRefreshToken
            }
            await auth.save()
            return true
        }

        // Only clear credentials when the authorization server has definitively
        // rejected the refresh token (400 / 401 — typically `invalid_grant`).
        // Transient failures (network errors, 5xx, timeouts) must leave the
        // tokens intact so we can retry later, otherwise a flaky network logs
        // the user out permanently.
        if let statusCode = response.response?.statusCode,
           statusCode == 400 || statusCode == 401 {
            auth.accessToken = nil
            auth.refreshToken = nil
            await auth.save()
        }

        return false
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

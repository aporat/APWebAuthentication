import Alamofire
import Foundation

// MARK: - GitHubInterceptor

/// Request interceptor for the GitHub API with OAuth 2.0 authentication.
///
/// `GitHubInterceptor` extends `OAuth2Interceptor` to provide GitHub-specific
/// request handling:
/// - OAuth 2.0 Bearer token authentication (standard Authorization header)
/// - GitHub API version header (`X-GitHub-Api-Version`)
/// - GitHub media type negotiation (`application/vnd.github+json`)
/// - Special handling for PUT requests (Content-Length header)
///
/// **Example Usage:**
/// ```swift
/// let auth = Auth2Authentication()
/// auth.accessToken = "ghp_..."
///
/// let interceptor = GitHubInterceptor(auth: auth)
/// // Automatically adds GitHub headers and OAuth token to all requests
/// ```
@MainActor
public final class GitHubInterceptor: OAuth2Interceptor, @unchecked Sendable {

    // MARK: - Initialization

    /// Creates a new GitHub API request interceptor.
    ///
    /// Configures the interceptor with GitHub's standard OAuth 2.0 settings:
    /// - Token location: Authorization header (standard OAuth 2.0)
    /// - Token format: `Bearer {access_token}`
    ///
    /// - Parameter auth: The OAuth 2.0 authentication credentials
    public init(auth: Auth2Authentication) {
        super.init(
            auth: auth,
            tokenLocation: .authorizationHeader,
            tokenParamName: "access_token",
            tokenHeaderParamName: "Bearer"
        )
    }

    // MARK: - Request Adaptation

    /// Adapts requests by adding GitHub-specific headers.
    ///
    /// **Headers Added:**
    /// - `Accept: application/vnd.github+json` - GitHub's media type
    /// - `X-GitHub-Api-Version: 2022-11-28` - API version
    /// - `Content-Length: 0` - Required for PUT requests
    ///
    /// Then calls parent to add OAuth token and standard headers.
    ///
    /// - Parameters:
    ///   - urlRequest: The request to adapt
    ///   - session: The Alamofire session
    ///   - completion: Completion handler with adapted request or error
    override nonisolated public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
    ) {
        var urlRequest = urlRequest

        // Add GitHub API headers
        urlRequest.headers.add(.accept("application/vnd.github+json"))
        urlRequest.headers.add(name: "X-GitHub-Api-Version", value: "2022-11-28")

        // GitHub requires Content-Length header for PUT requests
        if urlRequest.method == .put {
            urlRequest.headers.add(HTTPHeader(name: "Content-Length", value: "0"))
        }

        // Let parent add OAuth Bearer token and other headers
        super.adapt(urlRequest, for: session, completion: completion)
    }
}

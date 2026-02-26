import Alamofire
import Foundation
@preconcurrency import SwiftyJSON

// MARK: - GitHubAPIClient

/// HTTP client for the GitHub API with OAuth 2.0 authentication.
///
/// `GitHubAPIClient` provides authenticated access to the GitHub REST API.
/// It handles:
/// - OAuth 2.0 bearer token authentication
/// - GitHub-specific API versioning headers
/// - GitHub API media type negotiation
///
/// **Example Usage:**
/// ```swift
/// let auth = Auth2Authentication()
/// auth.accessToken = "ghp_..."
/// 
/// let client = GitHubAPIClient(auth: auth)
/// let repos = try await client.request("/user/repos")
/// let user = try await client.request("/user")
/// ```
///
/// - Note: GitHub uses standard OAuth 2.0 with Bearer tokens in the Authorization header.
@MainActor
public final class GitHubAPIClient: OAuth2Client {

    // MARK: - Initialization

    /// Creates a new GitHub API client with OAuth 2.0 authentication.
    ///
    /// - Parameter auth: The OAuth 2.0 authentication credentials
    public convenience init(auth: Auth2Authentication) {
        let interceptor = GitHubInterceptor(auth: auth)
        self.init(
            baseURLString: "https://api.github.com/",
            requestInterceptor: interceptor
        )
    }

    /// Creates a new GitHub API client with a custom base URL and interceptor.
    ///
    /// Use this for testing with mock servers or GitHub Enterprise instances.
    ///
    /// - Parameters:
    ///   - baseURLString: The base URL for all API requests
    ///   - requestInterceptor: The request interceptor for authentication
    public init(baseURLString: String, requestInterceptor: GitHubInterceptor) {
        super.init(
            accountType: AccountStore.github,
            baseURLString: baseURLString,
            requestInterceptor: requestInterceptor
        )
    }
}

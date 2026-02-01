import Foundation
import Alamofire

// MARK: - GitHubInterceptor

public final class GitHubInterceptor: OAuth2Interceptor, Sendable {
    
    // MARK: - Initialization
    
    public init(auth: Auth2Authentication) {
        super.init(
            auth: auth,
            tokenLocation: .authorizationHeader,
            tokenParamName: "access_token",
            tokenHeaderParamName: "Bearer"
        )
    }

    // MARK: - Request Adaptation
    
    nonisolated public override func adapt(
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

        super.adapt(urlRequest, for: session, completion: completion)
    }
}

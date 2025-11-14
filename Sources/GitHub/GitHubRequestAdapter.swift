import Foundation
import Alamofire

final class GitHubRequestAdapter: OAuth2RequestAdapter, @unchecked Sendable {
    override init(auth: Auth2Authentication) {
        super.init(auth: auth)
        tokenLocation = .authorizationHeader
    }

    override func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        var urlRequest = urlRequest

        urlRequest.headers.add(.accept("application/vnd.github+json"))
        urlRequest.headers.add(name: "X-GitHub-Api-Version", value: "2022-11-28")

        if urlRequest.method == HTTPMethod.put {
            urlRequest.headers.add(HTTPHeader(name: "Content-Length", value: "0"))
        }

        super.adapt(urlRequest, for: session, completion: completion)
    }
}

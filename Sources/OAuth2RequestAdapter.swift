import Foundation
import Alamofire

internal enum SCTokenLocation: Int {
    case authorizationHeader, params
}

open class OAuth2RequestAdapter: RequestAdapter, @unchecked Sendable {
    var tokenParamName = "access_token"
    var tokenHeaderParamName = "Bearer"
    var tokenLocation: SCTokenLocation = .params
    
    var auth: Auth2Authentication

    init(auth: Auth2Authentication) {
        self.auth = auth
    }

    public func adapt(_ urlRequest: URLRequest, for _: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        
        Task {
            var urlRequest = urlRequest

            if let currentUserAgent = await auth.userAgent, !currentUserAgent.isEmpty {
                urlRequest.headers.add(.userAgent(currentUserAgent))
            }

            let currentAccessToken = await auth.accessToken
            
            if let currentAccessToken, !currentAccessToken.isEmpty, tokenLocation == .authorizationHeader {
                urlRequest.headers.add(.authorization("\(tokenHeaderParamName) \(currentAccessToken)"))
            }

            urlRequest.headers.add(.accept("application/json"))

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

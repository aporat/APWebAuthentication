import Foundation
import Alamofire

internal enum TokenLocation: Int {
    case authorizationHeader, params
}

open class OAuth2Interceptor: RequestInterceptor, @unchecked Sendable {
    
    var tokenParamName = "access_token"
    var tokenHeaderParamName = "Bearer"
    var tokenLocation: TokenLocation = .params
    
    var auth: Auth2Authentication
    
    public init(auth: Auth2Authentication) {
        self.auth = auth
    }
    
    // MARK: - RequestAdapter
    
    public func adapt(_ urlRequest: URLRequest, for _: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        
        Task {
            var urlRequest = urlRequest
            
            if let currentUserAgent = await auth.userAgent, !currentUserAgent.isEmpty {
                urlRequest.headers.add(.userAgent(currentUserAgent))
            }
            
            let currentAccessToken = await auth.accessToken
            
            // 1. Handle Header Injection
            if let currentAccessToken, !currentAccessToken.isEmpty, tokenLocation == .authorizationHeader {
                urlRequest.headers.add(.authorization("\(tokenHeaderParamName) \(currentAccessToken)"))
            }
            
            urlRequest.headers.add(.accept("application/json"))
            
            // 2. Handle Parameter Injection
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

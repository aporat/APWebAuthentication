import Foundation
import Alamofire

public final class FoursquareInterceptor: OAuth2Interceptor, @unchecked Sendable {
    
    override init(auth: Auth2Authentication) {
        super.init(auth: auth)
        self.tokenParamName = "oauth_token"
    }
    
    public override func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        var urlRequest = urlRequest
        
        let params: Parameters = ["v": "20240109"]
        
        do {
            urlRequest = try URLEncoding.default.encode(urlRequest, with: params)
            super.adapt(urlRequest, for: session, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
}

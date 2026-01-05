import Foundation
import Alamofire

final class TwitchInterceptor: OAuth2Interceptor, @unchecked Sendable {
    
    override func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        
        Task {
            var urlRequest = urlRequest
            
            // Twitch Helix API requires the Client-ID header
            if let clientId = await self.auth.clientId {
                urlRequest.headers.add(HTTPHeader(name: "Client-ID", value: clientId))
            }
            
            super.adapt(urlRequest, for: session, completion: completion)
        }
    }
}

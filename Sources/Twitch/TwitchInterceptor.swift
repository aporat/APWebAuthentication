import Foundation
import Alamofire

// MARK: - TwitchInterceptor

public final class TwitchInterceptor: OAuth2Interceptor, @unchecked Sendable {
    
    // MARK: - Request Adaptation
    
    public override func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
    ) {
        Task {
            var urlRequest = urlRequest
            
            // Twitch Helix API requires the Client-ID header for all requests
            if let clientId = await self.auth.clientId {
                urlRequest.headers.add(HTTPHeader(name: "Client-ID", value: clientId))
            }
            
            // Call super to add OAuth token
            super.adapt(urlRequest, for: session, completion: completion)
        }
    }
}

import Foundation
import Alamofire

final class TwitchRequestAdapter: OAuth2RequestAdapter, @unchecked Sendable {
    
    override func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        
        super.adapt(urlRequest, for: session) { result in
            
            switch result {
            case .failure(let error):
                completion(.failure(error))
                
            case .success(var adaptedRequest):
                Task {
                    if let clientId = await self.auth.clientId {
                        adaptedRequest.headers.add(HTTPHeader(name: "Client-ID", value: clientId))
                    }
                    
                    completion(.success(adaptedRequest))
                }
            }
        }
    }
}

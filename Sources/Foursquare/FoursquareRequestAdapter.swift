import Foundation
import Alamofire

final class FoursquareRequestAdapter: OAuth2RequestAdapter, @unchecked Sendable {
    
    override func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        var urlRequest = urlRequest

        let params: Parameters = ["v": "20240109"]
        urlRequest = try! URLEncoding.default.encode(urlRequest, with: params)

        super.adapt(urlRequest, for: session, completion: completion)
    }
}

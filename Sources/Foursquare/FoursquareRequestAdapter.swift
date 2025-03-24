import Alamofire
import UIKit

final class FoursquareRequestAdapter: OAuth2RequestAdapter {
    override func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest

        let params: Parameters = ["v": "20240109"]
        urlRequest = try! URLEncoding.default.encode(urlRequest, with: params)

        super.adapt(urlRequest, for: session, completion: completion)
    }
}

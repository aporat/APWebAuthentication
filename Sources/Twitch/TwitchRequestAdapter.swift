import Alamofire
import UIKit

final class TwitchRequestAdapter: OAuth2RequestAdapter {
    override func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest

        if let clientId = auth.clientId {
            urlRequest.headers.add(HTTPHeader(name: "Client-ID", value: clientId))
        }

        super.adapt(urlRequest, for: session, completion: completion)
    }
}

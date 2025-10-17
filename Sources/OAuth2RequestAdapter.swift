import Foundation
import Alamofire

internal enum SCTokenLocation: Int {
    case authorizationHeader, params
}

open class OAuth2RequestAdapter: RequestAdapter {
    var tokenParamName = "access_token"
    var tokenHeaderParamName = "Bearer"
    var tokenLocation: SCTokenLocation = .params
    var auth: Auth2Authentication

    init(auth: Auth2Authentication) {
        self.auth = auth
    }

    public func adapt(_ urlRequest: URLRequest, for _: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest

        if let currentUserAgent = auth.userAgent, !currentUserAgent.isEmpty {
            urlRequest.headers.add(.userAgent(currentUserAgent))
        }

        if let currentAccessToken = auth.accessToken, !currentAccessToken.isEmpty, tokenLocation == .authorizationHeader {
            urlRequest.headers.add(.authorization("\(tokenHeaderParamName) \(currentAccessToken)"))
        }

        urlRequest.headers.add(.accept("application/json"))

        if let currentAccessToken = auth.accessToken, !currentAccessToken.isEmpty, tokenLocation == .params {
            let params: Parameters = [tokenParamName: currentAccessToken]

            completion(.success(try! URLEncoding.default.encode(urlRequest, with: params)))
            return
        }

        completion(.success(urlRequest))
    }
}

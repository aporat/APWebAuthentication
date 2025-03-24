import Alamofire
import UIKit

final class FiveHundredspxWebRequestAdapter: RequestAdapter {
    var auth: FiveHundredspxWebAuthentication

    init(auth: FiveHundredspxWebAuthentication) {
        self.auth = auth
    }

    func adapt(_ urlRequest: URLRequest, for _: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest

        if let currentUserAgent = auth.userAgent, !currentUserAgent.isEmpty {
            urlRequest.headers.add(.userAgent(currentUserAgent))
        }

        if let currentCSRF = auth.csrfToken {
            urlRequest.headers.add(HTTPHeader(name: "x-csrf-token", value: currentCSRF))
        }

        urlRequest.headers.add(HTTPHeader(name: "Referer", value: "https://500px.com"))
        urlRequest.headers.add(HTTPHeader(name: "Origin", value: "https://500px.com"))
        urlRequest.headers.add(.acceptLanguage(auth.localeWebIdentifier))
        urlRequest.headers.add(.accept("application/json, text/javascript, */*; q=0.01"))
        urlRequest.headers.add(.acceptEncoding("gzip, deflate, sdch, br"))

        completion(.success(urlRequest))
    }
}

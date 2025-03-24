import Alamofire
import UIKit

final class PinterestWebRequestAdapter: RequestAdapter {
    var auth: PinterestWebAuthentication

    init(auth: PinterestWebAuthentication) {
        self.auth = auth
    }

    func adapt(_ urlRequest: URLRequest, for _: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest

        if let currentUserAgent = auth.userAgent, !currentUserAgent.isEmpty {
            urlRequest.headers.add(.userAgent(currentUserAgent))
        }

        if let currentCSRF = auth.csrfToken {
            urlRequest.headers.add(HTTPHeader(name: "X-CSRFToken", value: currentCSRF))
        }

        urlRequest.headers.add(HTTPHeader(name: "X-Pinterest-AppState", value: "active"))
        urlRequest.headers.add(HTTPHeader(name: "x-app-version", value: auth.appId))
        urlRequest.headers.add(HTTPHeader(name: "X-Requested-With", value: "XMLHttpRequest"))

        urlRequest.headers.add(HTTPHeader(name: "Referer", value: "https://www.pinterest.com"))
        urlRequest.headers.add(HTTPHeader(name: "Origin", value: "https://www.pinterest.com"))
        urlRequest.headers.add(.acceptLanguage(auth.localeWebIdentifier))
        urlRequest.headers.add(.accept("application/json, text/javascript, */*; q=0.01"))
        urlRequest.headers.add(.acceptEncoding("gzip, deflate, sdch, br"))

        completion(.success(urlRequest))
    }
}

import Alamofire
import UIKit

final class PinterestWebHTMLRequestAdapter: RequestAdapter {
    var auth: PinterestWebAuthentication

    init(auth: PinterestWebAuthentication) {
        self.auth = auth
    }

    func adapt(_ urlRequest: URLRequest, for _: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest

        if let currentUserAgent = auth.userAgent, !currentUserAgent.isEmpty {
            urlRequest.headers.add(.userAgent(currentUserAgent))
        }

        urlRequest.headers.add(HTTPHeader(name: "Referer", value: "https://www.pinterest.com"))
        urlRequest.headers.add(HTTPHeader(name: "Origin", value: "https://www.pinterest.com"))
        urlRequest.headers.add(.acceptLanguage(auth.localeWebIdentifier))
        urlRequest.headers.add(.accept("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"))
        urlRequest.headers.add(.acceptEncoding("gzip, deflate, sdch, br"))
        urlRequest.headers.add(HTTPHeader(name: "Connection", value: "keep-alive"))

        completion(.success(urlRequest))
    }
}

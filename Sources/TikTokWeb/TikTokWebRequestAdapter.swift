import Alamofire
import UIKit

final class TikTokWebRequestAdapter: RequestAdapter {
    var auth: TikTokWebAuthentication

    init(auth: TikTokWebAuthentication) {
        self.auth = auth
    }

    func adapt(_ urlRequest: URLRequest, for _: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest

        urlRequest.headers.add(HTTPHeader(name: "authority", value: "www.tiktok.com"))
        urlRequest.headers.add(.accept("application/json, text/plain, */*"))

        if let currentUserAgent = auth.userAgent, !currentUserAgent.isEmpty {
            urlRequest.headers.add(.userAgent(currentUserAgent))
        }

        urlRequest.headers.add(HTTPHeader(name: "sec-fetch-site", value: "same-origin"))
        urlRequest.headers.add(HTTPHeader(name: "sec-fetch-mode", value: "cors"))
        urlRequest.headers.add(HTTPHeader(name: "sec-fetch-dest", value: "empty"))

        if urlRequest.method != HTTPMethod.get {
            if let currentCSRF = auth.csrfToken {
                urlRequest.headers.add(HTTPHeader(name: "x-csrf-token", value: currentCSRF))
            }
        }

        urlRequest.headers.add(HTTPHeader(name: "Origin", value: "https://www.tiktok.com"))
        urlRequest.headers.add(.acceptLanguage(auth.localeWebIdentifier))

        completion(.success(urlRequest))
    }
}

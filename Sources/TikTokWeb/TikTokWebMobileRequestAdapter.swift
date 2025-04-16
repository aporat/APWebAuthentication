import Foundation
import Alamofire

final class TikTokWebMobileRequestAdapter: RequestAdapter, @unchecked Sendable {
    var auth: TikTokWebAuthentication

    init(auth: TikTokWebAuthentication) {
        self.auth = auth
    }

    func adapt(_ urlRequest: URLRequest, for _: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest

        urlRequest.headers.add(HTTPHeader(name: "authority", value: "m.tiktok.com"))
        urlRequest.headers.add(.accept("application/json, text/plain, */*"))

        if let currentUserAgent = auth.userAgent, !currentUserAgent.isEmpty {
            urlRequest.headers.add(.userAgent(currentUserAgent))
        }

        urlRequest.headers.add(HTTPHeader(name: "origin", value: "https://www.tiktok.com"))
        urlRequest.headers.add(HTTPHeader(name: "sec-fetch-site", value: "same-site"))
        urlRequest.headers.add(HTTPHeader(name: "sec-fetch-mode", value: "cors"))
        urlRequest.headers.add(HTTPHeader(name: "sec-fetch-dest", value: "empty"))

        urlRequest.headers.add(.acceptLanguage(auth.localeWebIdentifier))

        completion(.success(urlRequest))
    }
}

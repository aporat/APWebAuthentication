import Foundation
import Alamofire

final class TikTokWebMobileRequestAdapter: RequestAdapter, @unchecked Sendable {
    @MainActor
    var auth: TikTokWebAuthentication

    @MainActor
    init(auth: TikTokWebAuthentication) {
        self.auth = auth
    }

    public func adapt(_ urlRequest: URLRequest, for _: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        Task {
            var urlRequest = urlRequest

            urlRequest.headers.add(HTTPHeader(name: "authority", value: "m.tiktok.com"))
            urlRequest.headers.add(.accept("application/json, text/plain, */*"))

            // REFACTOR: `await` @MainActor property
            if let currentUserAgent = await auth.userAgent, !currentUserAgent.isEmpty {
                urlRequest.headers.add(.userAgent(currentUserAgent))
            }

            urlRequest.headers.add(HTTPHeader(name: "origin", value: "https://www.tiktok.com"))
            urlRequest.headers.add(HTTPHeader(name: "sec-fetch-site", value: "same-site"))
            urlRequest.headers.add(HTTPHeader(name: "sec-fetch-mode", value: "cors"))
            urlRequest.headers.add(HTTPHeader(name: "sec-fetch-dest", value: "empty"))

            let locale = await auth.localeWebIdentifier
            urlRequest.headers.add(.acceptLanguage(locale))

            completion(.success(urlRequest))
        }
    }
}

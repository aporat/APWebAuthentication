import Alamofire
import Foundation

public final class TikTokWebInterceptor: RequestInterceptor, Sendable {

    @MainActor
    var auth: TikTokWebAuthentication

    @MainActor
    public init(auth: TikTokWebAuthentication) {
        self.auth = auth
    }

    // MARK: - RequestAdapter

    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
            // Hop to MainActor once instead of awaiting each `auth` property
        // independently — every separate `await` is another suspension the
        // auth state can change across, which would let one request go out
        // carrying a mix of old and new credentials.

        Task { @MainActor in
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

            let locale = auth.localeWebIdentifier
            urlRequest.headers.add(.acceptLanguage(locale))

            completion(.success(urlRequest))
        }
    }
}

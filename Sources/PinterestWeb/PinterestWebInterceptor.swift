import Alamofire
import Foundation

// MARK: - PinterestWebInterceptor

public final class PinterestWebInterceptor: RequestInterceptor, Sendable {

    // MARK: - Properties

    @MainActor
    var auth: PinterestWebAuthentication

    // MARK: - Initialization

    @MainActor
    public init(auth: PinterestWebAuthentication) {
        self.auth = auth
    }

    // MARK: - RequestAdapter

    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
    ) {
        Task {
            var urlRequest = urlRequest

            // Add user agent
            if let currentUserAgent = await auth.userAgent, !currentUserAgent.isEmpty {
                urlRequest.headers.add(.userAgent(currentUserAgent))
            }

            // Add CSRF token
            if let currentCSRF = await auth.csrfToken {
                urlRequest.headers.add(HTTPHeader(name: "X-CSRFToken", value: currentCSRF))
            }

            // Add Pinterest-specific headers
            let appId = await auth.appId
            urlRequest.headers.add(HTTPHeader(name: "x-pinterest-appstate", value: "active"))
            urlRequest.headers.add(HTTPHeader(name: "x-app-version", value: appId))
            urlRequest.headers.add(HTTPHeader(name: "X-Requested-With", value: "XMLHttpRequest"))

            // Add origin and referer
            urlRequest.headers.add(HTTPHeader(name: "Referer", value: "https://www.pinterest.com"))
            urlRequest.headers.add(HTTPHeader(name: "Origin", value: "https://www.pinterest.com"))

            // Add locale and content headers
            let locale = await auth.localeWebIdentifier
            urlRequest.headers.add(.acceptLanguage(locale))
            urlRequest.headers.add(.accept("application/json, text/javascript, */*; q=0.01"))
            urlRequest.headers.add(.acceptEncoding("gzip, deflate, sdch, br"))

            // Add CORS/Fetch metadata for non-GET requests
            if urlRequest.method != .get {
                urlRequest.headers.add(HTTPHeader(name: "sec-fetch-dest", value: "empty"))
                urlRequest.headers.add(HTTPHeader(name: "sec-fetch-mode", value: "cors"))
                urlRequest.headers.add(HTTPHeader(name: "sec-fetch-site", value: "same-origin"))
            }

            // Add PWS handler and source URL
            urlRequest.headers.add(HTTPHeader(name: "x-pinterest-pws-handler", value: "www/[username]/_profile.js"))

            if let username = await auth.username {
                urlRequest.headers.add(HTTPHeader(name: "x-pinterest-source-url", value: "/\(username)/_profile/"))
            }

            completion(.success(urlRequest))
        }
    }
}

import Alamofire
import Foundation

// MARK: - PinterestWebHTMLAPIClient

@MainActor
public final class PinterestWebHTMLAPIClient: AuthClient {

    // MARK: - Properties

    private var interceptor: PinterestWebHTMLInterceptor
    private let auth: PinterestWebAuthentication

    // MARK: - Initialization

    public required convenience init(auth: PinterestWebAuthentication) {
        let interceptor = PinterestWebHTMLInterceptor(auth: auth)
        self.init(baseURLString: "https://www.pinterest.com/", auth: auth, requestInterceptor: interceptor)
    }

    public init(baseURLString: String, auth: PinterestWebAuthentication, requestInterceptor: PinterestWebHTMLInterceptor) {
        self.auth = auth
        self.interceptor = requestInterceptor
        super.init(accountType: AccountStore.pinterest, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }

    // MARK: - Session Configuration

    override public func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = auth.cookieStorage
        return configuration
    }
}

import Alamofire
import UIKit

public final class TikTokWebMobileAPIClient: AuthClient {
    fileprivate var requestAdapter: TikTokWebMobileRequestAdapter

    public required convenience init(auth: TikTokWebAuthentication) {
        self.init(baseURLString: "https://m.tiktok.com/", auth: auth)
    }

    public init(baseURLString: String, auth: TikTokWebAuthentication) {
        requestAdapter = TikTokWebMobileRequestAdapter(auth: auth)
        super.init(baseURLString: baseURLString)

        requestInterceptor = Interceptor(adapters: [requestAdapter], retriers: [requestRetrier])

        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = auth.cookieStorage
        sessionManager = makeSessionManager(configuration: configuration)
    }
}

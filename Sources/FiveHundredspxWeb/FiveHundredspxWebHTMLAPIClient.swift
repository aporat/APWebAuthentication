import Alamofire
import UIKit

public final class FiveHundredspxWebHTMLAPIClient: AuthClient {
    fileprivate var requestAdapter: FiveHundredspxWebHTMLRequestAdapter

    public required convenience init(auth: FiveHundredspxWebAuthentication) {
        self.init(baseURLString: "https://web.500px.com/", auth: auth)
    }

    public init(baseURLString: String, auth: FiveHundredspxWebAuthentication) {
        requestAdapter = FiveHundredspxWebHTMLRequestAdapter(auth: auth)
        super.init(baseURLString: baseURLString)

        requestInterceptor = Interceptor(adapters: [requestAdapter], retriers: [requestRetrier])

        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = auth.cookieStorage
        sessionManager = makeSessionManager(configuration: configuration)
    }
}

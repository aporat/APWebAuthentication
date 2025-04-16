import Foundation
import Alamofire

public final class PinterestWebHTMLAPIClient: AuthClient {
    fileprivate var requestAdapter: PinterestWebHTMLRequestAdapter

    public required convenience init(auth: PinterestWebAuthentication) {
        self.init(baseURLString: "https://www.pinterest.com/", auth: auth)
    }

    public init(baseURLString: String, auth: PinterestWebAuthentication) {
        requestAdapter = PinterestWebHTMLRequestAdapter(auth: auth)
        super.init(baseURLString: baseURLString)
        requestInterceptor = Interceptor(adapters: [requestAdapter], retriers: [requestRetrier])

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = auth.cookieStorage
        sessionManager = makeSessionManager(configuration: configuration)
    }
}

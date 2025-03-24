import Alamofire
import SwiftyJSON
import UIKit


public final class FiveHundredspxWebAPIClient: AuthClient {
    fileprivate var requestAdapter: FiveHundredspxWebRequestAdapter

    public required convenience init(auth: FiveHundredspxWebAuthentication) {
        self.init(baseURLString: "https://api.500px.com/v1/", auth: auth)
    }

    public init(baseURLString: String, auth: FiveHundredspxWebAuthentication) {
        requestAdapter = FiveHundredspxWebRequestAdapter(auth: auth)
        super.init(baseURLString: baseURLString)

        requestInterceptor = Interceptor(adapters: [requestAdapter], retriers: [requestRetrier])

        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = auth.cookieStorage
        sessionManager = makeSessionManager(configuration: configuration)
    }

    public func loadSettings(_ options: JSON?) {
        if let value = options?["keep_device_settings"].bool {
            requestAdapter.auth.keepDeviceSettings = value
        }

        if let value = ProviderBrowserMode(options?["browser_mode"].string) {
            requestAdapter.auth.browserMode = value
        }

        if let value = options?["custom_user_agent"].string {
            requestAdapter.auth.customUserAgent = value
        }

        if let value = options?["cookies_domain"].string {
            requestAdapter.auth.cookiesDomain = value
        }

        if let value = options?["cookie_session_id_field"].string {
            requestAdapter.auth.cookieSessionIdField = value
        }
    }
}

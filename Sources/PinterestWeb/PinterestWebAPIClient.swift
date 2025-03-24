import Alamofire
import SwiftyJSON
import Foundation

public final class PinterestWebAPIClient: AuthClient {
    fileprivate var requestAdapter: PinterestWebRequestAdapter

    public required convenience init(auth: PinterestWebAuthentication) {
        self.init(baseURLString: "https://www.pinterest.com/", auth: auth)
    }

    public init(baseURLString: String, auth: PinterestWebAuthentication) {
        requestAdapter = PinterestWebRequestAdapter(auth: auth)
        super.init(baseURLString: baseURLString)

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

        if let value = options?["app_id"].string {
            requestAdapter.auth.appId = value
        }
    }
}

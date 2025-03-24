import Alamofire
import SwiftyJSON
import Foundation

public final class TikTokWebAPIClient: AuthClient {
    fileprivate var requestAdapter: TikTokWebRequestAdapter

    public required convenience init(auth: TikTokWebAuthentication) {
        self.init(baseURLString: "https://www.tiktok.com/", auth: auth)
    }

    public init(baseURLString: String, auth: TikTokWebAuthentication) {
        requestAdapter = TikTokWebRequestAdapter(auth: auth)
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

        if let value = options?["signature_url"].url {
            requestAdapter.auth.signatureUrl = value
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

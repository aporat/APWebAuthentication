import Alamofire
import SwiftyJSON
import Foundation

public final class FoursquareAPIClient: AuthClient {
    fileprivate var requestAdapter: FoursquareRequestAdapter

    public convenience init(auth: Auth2Authentication) {
        self.init(baseURLString: "https://api.foursquare.com/v2/", auth: auth)
    }

    public init(baseURLString: String, auth: Auth2Authentication) {
        requestAdapter = FoursquareRequestAdapter(auth: auth)
        requestAdapter.tokenParamName = "oauth_token"
        super.init(baseURLString: baseURLString)

        requestInterceptor = Interceptor(adapters: [requestAdapter], retriers: [requestRetrier])

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        sessionManager = makeSessionManager(configuration: configuration)
    }

    public func loadSettings(_ options: JSON?) {
        if let value = ProviderBrowserMode(options?["browser_mode"].string) {
            requestAdapter.auth.browserMode = value
        }

        if let value = options?["custom_user_agent"].string {
            requestAdapter.auth.customUserAgent = value
        }
    }
}

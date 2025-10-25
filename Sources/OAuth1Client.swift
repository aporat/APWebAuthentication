import Foundation
import Alamofire
import SwiftyJSON

open class OAuth1Client: AuthClient {
    fileprivate var requestAdapter: OAuth1RequestAdapter

    public init(baseURLString: String, consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        requestAdapter = OAuth1RequestAdapter(consumerKey: consumerKey, consumerSecret: consumerSecret, auth: auth)
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

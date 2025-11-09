import Foundation
import Alamofire
import SwiftyJSON

open class OAuth1Client: AuthClient {
    fileprivate var requestAdapter: OAuth1RequestAdapter
    
    public init(baseURLString: String, consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        let requestAdapter = OAuth1RequestAdapter(consumerKey: consumerKey, consumerSecret: consumerSecret, auth: auth)
        let retrier = AuthClientRequestRetrier()
        let interceptor = Interceptor(adapters: [requestAdapter], retriers: [retrier])
        
        self.requestAdapter = requestAdapter
        super.init(baseURLString: baseURLString, requestInterceptor: interceptor)
        
        self.requestRetrier = retrier
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

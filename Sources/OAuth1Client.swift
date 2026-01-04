import Foundation
import Alamofire
import SwiftyJSON

open class OAuth1Client: AuthClient {
    fileprivate var requestAdapter: OAuth1RequestAdapter
    
    public init(baseURLString: String, consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        let requestAdapter = OAuth1RequestAdapter(consumerKey: consumerKey, consumerSecret: consumerSecret, auth: auth)
        let interceptor = Interceptor(adapters: [requestAdapter])
        
        self.requestAdapter = requestAdapter
        super.init(baseURLString: baseURLString, requestInterceptor: interceptor)
        
    }
    
    public func loadSettings(_ options: JSON?) async {
        if let value = UserAgentMode(options?["browser_mode"].string) {
            requestAdapter.auth.setBrowserMode(value)
        }
        
        if let value = options?["custom_user_agent"].string {
            requestAdapter.auth.setCustomUserAgent(value)
        }
    }
}

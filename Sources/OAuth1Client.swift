import Foundation
import Alamofire
import SwiftyJSON

open class OAuth1Client: AuthClient {
    
    // MARK: - Properties
    
    fileprivate var interceptor: OAuth1Interceptor
    
    // MARK: - Initialization
    
    public init(baseURLString: String, consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        let interceptor = OAuth1Interceptor(consumerKey: consumerKey, consumerSecret: consumerSecret, auth: auth)
        
        self.interceptor = interceptor
        super.init(baseURLString: baseURLString, requestInterceptor: interceptor)
    }
    
    // MARK: - Configuration
    
    public func loadSettings(_ options: JSON?) async {
        if let value = UserAgentMode(options?["browser_mode"].string) {
            interceptor.auth.setBrowserMode(value)
        }
        
        if let value = options?["custom_user_agent"].string {
            interceptor.auth.setCustomUserAgent(value)
        }
    }
}

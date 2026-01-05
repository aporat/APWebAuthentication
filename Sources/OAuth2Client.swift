import Foundation
import Alamofire
import SwiftyJSON

open class OAuth2Client: AuthClient {
    
    public var interceptor: OAuth2Interceptor
    
    public convenience init(baseURLString: String, auth: Auth2Authentication) {
        let interceptor = OAuth2Interceptor(auth: auth)
        
        self.init(baseURLString: baseURLString, requestInterceptor: interceptor)
    }
    
    public override init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        // Direct cast validation
        guard let customInterceptor = requestInterceptor as? OAuth2Interceptor else {
            fatalError("OAuth2Client requires an OAuth2Interceptor (or subclass).")
        }
        
        self.interceptor = customInterceptor
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
    
    public func loadSettings(_ options: JSON?) async {
        if let value = UserAgentMode(options?["browser_mode"].string) {
            interceptor.auth.setBrowserMode(value)
        }
        
        if let value = options?["custom_user_agent"].string {
            interceptor.auth.setCustomUserAgent(value)
        }
    }
}

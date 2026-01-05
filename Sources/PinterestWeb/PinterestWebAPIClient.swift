import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

@MainActor
public final class PinterestWebAPIClient: AuthClient {
    
    // MARK: - Properties
    
    public override var accountType: AccountType {
        AccountStore.pinterest
    }
    
    fileprivate var interceptor: PinterestWebInterceptor
    fileprivate let auth: PinterestWebAuthentication
    
    // MARK: - Initialization
    
    public required convenience init(auth: PinterestWebAuthentication) {
        let interceptor = PinterestWebInterceptor(auth: auth)
        // Pass the interceptor directly, no wrapper needed
        self.init(baseURLString: "https://www.pinterest.com/", auth: auth, requestInterceptor: interceptor)
    }
    
    public init(baseURLString: String, auth: PinterestWebAuthentication, requestInterceptor: RequestInterceptor) {
        guard let customInterceptor = requestInterceptor as? PinterestWebInterceptor else {
            fatalError("PinterestWebAPIClient requires a PinterestWebInterceptor.")
        }
        
        self.auth = auth
        self.interceptor = customInterceptor
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
    
    public override func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = auth.cookieStorage
        return configuration
    }
    
    // MARK: - Configuration
    
    public func loadSettings(_ options: JSON?) {
        if let value = options?["keep_device_settings"].bool {
            interceptor.auth.keepDeviceSettings = value
        }
        
        if let value = UserAgentMode(options?["browser_mode"].string) {
            interceptor.auth.browserMode = value
        }
        
        if let value = options?["custom_user_agent"].string {
            interceptor.auth.customUserAgent = value
        }
        
        if let value = options?["cookies_domain"].string {
            interceptor.auth.cookiesDomain = value
        }
        
        if let value = options?["app_id"].string {
            interceptor.auth.appId = value
        }
    }
    
    // MARK: - Error Handling
    
    public override func extractErrorMessage(from json: JSON?) -> String? {
        if let message = json?["resource_response"]["error"]["message"].string {
            return message
        }
        if let message = json?["error"]["message"].string {
            return message
        }
        return super.extractErrorMessage(from: json)
    }
}

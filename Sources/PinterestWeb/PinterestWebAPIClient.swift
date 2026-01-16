import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

// MARK: - PinterestWebAPIClient

@MainActor
public final class PinterestWebAPIClient: AuthClient {
    
    // MARK: - Properties
    
    public override var accountType: AccountType {
        AccountStore.pinterest
    }
    
    private var interceptor: PinterestWebInterceptor
    private let auth: PinterestWebAuthentication
    
    // MARK: - Initialization
    
    public required convenience init(auth: PinterestWebAuthentication) {
        let interceptor = PinterestWebInterceptor(auth: auth)
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
    
    // MARK: - Session Configuration
    
    public override func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = auth.cookieStorage
        return configuration
    }
    
    // MARK: - Configuration
    
    public func loadSettings(_ options: JSON?) {
        // Keep device settings flag
        if let value = options?["keep_device_settings"].bool {
            interceptor.auth.keepDeviceSettings = value
        }
        
        // Browser mode configuration
        if let value = UserAgentMode(options?["browser_mode"].string) {
            interceptor.auth.browserMode = value
        }
        
        // Custom user agent
        if let value = options?["custom_user_agent"].string {
            interceptor.auth.customUserAgent = value
        }
        
        // Cookies domain
        if let value = options?["cookies_domain"].string {
            interceptor.auth.cookiesDomain = value
        }
        
        // App ID
        if let value = options?["app_id"].string {
            interceptor.auth.appId = value
        }
    }
    
    // MARK: - Error Handling
    
    public override func extractErrorMessage(from json: JSON?) -> String? {
        // Check nested error structure
        if let message = json?["resource_response"]["error"]["message"].string {
            return message
        }
        
        // Check simple error structure
        if let message = json?["error"]["message"].string {
            return message
        }
        
        return super.extractErrorMessage(from: json)
    }
}

import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public final class PinterestWebAPIClient: AuthClient {
    
    public override var accountType: AccountType {
        AccountStore.pinterest
    }
    
    fileprivate var requestAdapter: PinterestWebRequestAdapter
    fileprivate let auth: PinterestWebAuthentication
    
    public required convenience init(auth: PinterestWebAuthentication) {
        let requestAdapter = PinterestWebRequestAdapter(auth: auth)
        let retrier = AuthClientRequestRetrier()
        let interceptor = Interceptor(adapters: [requestAdapter], retriers: [retrier])
        
        self.init(baseURLString: "https://www.pinterest.com/", auth: auth, requestInterceptor: interceptor)
        
        self.requestRetrier = retrier
    }
    
    public init(baseURLString: String, auth: PinterestWebAuthentication, requestInterceptor: RequestInterceptor) {
        self.auth = auth
        self.requestAdapter = (requestInterceptor as! Interceptor).adapters.first as! PinterestWebRequestAdapter
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
    
    public override func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = auth.cookieStorage
        return configuration
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

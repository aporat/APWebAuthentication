import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public class TikTokWebAPIClient: AuthClient {
    
    public override var accountType: AccountType {
        AccountStore.tiktok
    }
    
    fileprivate var requestAdapter: TikTokWebRequestAdapter
    
    public init(auth: TikTokWebAuthentication) {
        requestAdapter = TikTokWebRequestAdapter(auth: auth)
        super.init(baseURLString: "https://www.tiktok.com/")
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
    
    public override func extractErrorMessage(from json: JSON?) -> String? {
        if let message = json?["status_msg"].string {
            return message
        }
        if let message = json?["errMsg"].string {
            return message
        }
        if let message = json?["resource_response"]["error"]["message"].string {
            return message
        }
        if let message = json?["error"]["message"].string {
            return message
        }
        return super.extractErrorMessage(from: json)
    }
}

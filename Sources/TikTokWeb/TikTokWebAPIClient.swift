import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public class TikTokWebAPIClient: AuthClient {
    
    public override var accountType: AccountType {
        AccountStore.tiktok
    }
    
    fileprivate var requestAdapter: TikTokWebRequestAdapter
    
    public convenience init(auth: TikTokWebAuthentication) {
        let requestAdapter = TikTokWebRequestAdapter(auth: auth)
        let retrier = AuthClientRequestRetrier()
        let interceptor = Interceptor(adapters: [requestAdapter], retriers: [retrier])
        
        self.init(baseURLString: "https://www.tiktok.com/", requestInterceptor: interceptor)
        
        self.requestRetrier = retrier
    }
    
    public override init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        guard let interceptor = requestInterceptor as? Interceptor,
              let adapter = interceptor.adapters.first as? TikTokWebRequestAdapter
        else {
            fatalError("Failed to extract RequestInterceptor from requestInterceptor.")
        }
        
        self.requestAdapter = adapter
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
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

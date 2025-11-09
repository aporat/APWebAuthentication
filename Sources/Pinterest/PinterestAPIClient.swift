import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public final class PinterestAPIClient: AuthClient {
    
    public override var accountType: AccountType {
        AccountStore.pinterest
    }
    
    fileprivate var requestAdapter: OAuth2RequestAdapter
    
    public required convenience init(auth: Auth2Authentication) {
        let requestAdapter = OAuth2RequestAdapter(auth: auth)
        requestAdapter.tokenLocation = .authorizationHeader
        
        let retrier = AuthClientRequestRetrier()
        let interceptor = Interceptor(adapters: [requestAdapter], retriers: [retrier])
        
        self.init(baseURLString: "https://api.pinterest.com/v5/", requestInterceptor: interceptor)
        
        self.requestRetrier = retrier
    }
    
    public override init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        guard let interceptor = requestInterceptor as? Interceptor,
              let adapter = interceptor.adapters.first as? OAuth2RequestAdapter
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
        if let message = json?["message"].string {
            return message
        }
        
        // Check older patterns just in case, similar to PinterestWebAPIClient
        if let message = json?["resource_response"]["error"]["message"].string {
            return message
        }
        if let message = json?["error"]["message"].string {
            return message
        }
        return super.extractErrorMessage(from: json)
    }
}

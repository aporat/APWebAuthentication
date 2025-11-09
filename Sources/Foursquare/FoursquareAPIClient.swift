import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public final class FoursquareAPIClient: AuthClient {
    
    public override var accountType: AccountType {
        AccountStore.foursquare
    }
    
    fileprivate var requestAdapter: FoursquareRequestAdapter
    
    public convenience init(auth: Auth2Authentication) {
        let requestAdapter = FoursquareRequestAdapter(auth: auth)
        requestAdapter.tokenParamName = "oauth_token"
        
        let retrier = AuthClientRequestRetrier()
        let interceptor = Interceptor(adapters: [requestAdapter], retriers: [retrier])
        
        self.init(baseURLString: "https://api.foursquare.com/v2/", requestInterceptor: interceptor)
        
        self.requestAdapter = requestAdapter
        self.requestRetrier = retrier
    }
    
    public override init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        guard let interceptor = requestInterceptor as? Interceptor,
              let adapter = interceptor.adapters.first as? FoursquareRequestAdapter
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
        if let message = json?["meta"]["errorDetail"].string {
            return message
        }
        
        return super.extractErrorMessage(from: json)
    }
}

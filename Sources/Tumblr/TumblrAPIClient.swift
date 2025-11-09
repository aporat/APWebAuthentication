import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public final class TumblrAPIClient: AuthClient {

    public override var accountType: AccountType {
        AccountStore.tumblr
    }
    
    fileprivate var requestAdapter: OAuth2RequestAdapter

    public required convenience init(auth: Auth2Authentication) {
        let requestAdapter = OAuth2RequestAdapter(auth: auth)
        requestAdapter.tokenLocation = .authorizationHeader // Use Bearer token
        
        let retrier = AuthClientRequestRetrier()
        let interceptor = Interceptor(adapters: [requestAdapter], retriers: [retrier])

        self.init(baseURLString: "https://api.tumblr.com/v2/", requestInterceptor: interceptor)
        
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

    override public func extractErrorMessage(from json: JSON?) -> String? {
        if let message = json?["meta"]["msg"].string {
            return message
        }
        if let message = json?["response"]["errors"].array?.first?.string {
            return message
        }
        return super.extractErrorMessage(from: json)
    }

    override public func isSessionExpiredError(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        return super.isSessionExpiredError(response: response, json: json) || json?["meta"]["status"].int == 401
    }
}

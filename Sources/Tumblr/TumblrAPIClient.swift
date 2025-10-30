import Foundation
import Alamofire
@preconcurrency import SwiftyJSON
import AlamofireSwiftyJSON

public final class TumblrAPIClient: AuthClient {

    public override var accountType: AccountType {
        AccountStore.tumblr
    }
    
    fileprivate var requestAdapter: OAuth2RequestAdapter

    // --- NEW: Init for Auth2Authentication ---
    public required convenience init(auth: Auth2Authentication) {
        self.init(baseURLString: "https://api.tumblr.com/v2/", auth: auth)
    }

    public init(baseURLString: String, auth: Auth2Authentication) {
        requestAdapter = OAuth2RequestAdapter(auth: auth)
        requestAdapter.tokenLocation = .authorizationHeader // Use Bearer token
        super.init(baseURLString: baseURLString)

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

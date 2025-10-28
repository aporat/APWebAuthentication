import Foundation
import Alamofire
import SwiftyJSON

public final class RedditAPIClient: AuthClient {
    
    public override var accountType: AccountType {
        AccountStore.reddit
    }
    
    fileprivate var requestAdapter: OAuth2RequestAdapter

    public required convenience init(auth: Auth2Authentication) {
        self.init(baseURLString: "https://oauth.reddit.com/api/v1/", auth: auth)
    }

    public init(baseURLString: String, auth: Auth2Authentication) {
        requestAdapter = OAuth2RequestAdapter(auth: auth)
        requestAdapter.tokenLocation = .authorizationHeader
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
}

import Foundation
import Alamofire
@preconcurrency import SwiftyJSON
import AlamofireSwiftyJSON

public class GitHubAPIClient: AuthClient {
    
    public override var accountType: AccountType {
        AccountStore.github
    }
    
    
    fileprivate var requestAdapter: GitHubRequestAdapter
    
    public convenience init(auth: Auth2Authentication) {
        self.init(baseURLString: "https://api.github.com/", auth: auth)
    }
    
    public init(baseURLString: String, auth: Auth2Authentication) {
        requestAdapter = GitHubRequestAdapter(auth: auth)
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

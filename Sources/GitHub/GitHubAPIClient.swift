import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public class GitHubAPIClient: AuthClient {
    
    public override var accountType: AccountType {
        AccountStore.github
    }
    
    fileprivate var requestAdapter: GitHubRequestAdapter
    
    public convenience init(auth: Auth2Authentication) {
        let requestAdapter = GitHubRequestAdapter(auth: auth)
        let retrier = AuthClientRequestRetrier()
        let interceptor = Interceptor(adapters: [requestAdapter], retriers: [retrier])
        
        self.init(baseURLString: "https://api.github.com/", requestInterceptor: interceptor)
        
        self.requestRetrier = retrier
    }
    
    public override init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        guard let interceptor = requestInterceptor as? Interceptor,
              let adapter = interceptor.adapters.first as? GitHubRequestAdapter
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
    
}

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
        let interceptor = Interceptor(adapters: [requestAdapter])
        
        self.init(baseURLString: "https://api.github.com/", requestInterceptor: interceptor)
        
        self.requestAdapter = requestAdapter
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
    
    public func loadSettings(_ options: JSON?) async {
        if let value = UserAgentMode(options?["browser_mode"].string) {
            requestAdapter.auth.setBrowserMode(value)
        }
        
        if let value = options?["custom_user_agent"].string {
            requestAdapter.auth.setCustomUserAgent(value)
        }
    }
    
}

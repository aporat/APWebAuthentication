import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

// MARK: - GitHubAPIClient

public final class GitHubAPIClient: OAuth2Client {
    
    // MARK: - Properties
    
    public override var accountType: AccountType {
        AccountStore.github
    }
    
    // MARK: - Initialization
    
    public convenience init(auth: Auth2Authentication) {
        let interceptor = GitHubInterceptor(auth: auth)
        self.init(baseURLString: "https://api.github.com/", requestInterceptor: interceptor)
    }
    
    public override init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        guard requestInterceptor is GitHubInterceptor else {
            fatalError("GitHubAPIClient requires a GitHubInterceptor.")
        }
        
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
}

import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public final class RedditAPIClient: OAuth2Client {
    
    // MARK: - Properties
    
    public override var accountType: AccountType {
        AccountStore.reddit
    }
    
    // MARK: - Initialization
    
    public convenience init(auth: Auth2Authentication) {
        let interceptor = OAuth2Interceptor(auth: auth)
        interceptor.tokenLocation = .authorizationHeader
        
        self.init(baseURLString: "https://oauth.reddit.com/api/v1/", requestInterceptor: interceptor)
    }
    
    public override init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        guard requestInterceptor is OAuth2Interceptor else {
            fatalError("RedditAPIClient requires an OAuth2Interceptor.")
        }
        
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
}

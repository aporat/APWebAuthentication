import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

// MARK: - RedditAPIClient

public final class RedditAPIClient: OAuth2Client {

    // MARK: - Initialization

    public convenience init(auth: Auth2Authentication) {
        let interceptor = OAuth2Interceptor(auth: auth, tokenLocation: .authorizationHeader)

        self.init(baseURLString: "https://oauth.reddit.com/api/v1/", requestInterceptor: interceptor)
    }

    public init(baseURLString: String, requestInterceptor: OAuth2Interceptor) {
        super.init(accountType: AccountStore.reddit, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
}

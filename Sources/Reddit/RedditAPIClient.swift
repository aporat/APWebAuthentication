import Alamofire
import Foundation
@preconcurrency import SwiftyJSON

// MARK: - RedditAPIClient

public final class RedditAPIClient: OAuth2Client {

    // MARK: - Initialization

    /// Reddit's token endpoint, used for the refresh-token grant.
    public static let refreshTokenURL = "https://www.reddit.com/api/v1/access_token"

    public convenience init(auth: Auth2Authentication) {
        // Reddit requires HTTP Basic client authentication on every token
        // request; installed apps have no secret and send `client_id:` with
        // an empty password (https://github.com/reddit-archive/reddit/wiki/OAuth2).
        // Refresh tokens are only issued for `duration=permanent` grants.
        let interceptor = OAuth2Interceptor(
            auth: auth,
            tokenLocation: .authorizationHeader,
            refreshTokenURL: Self.refreshTokenURL,
            clientAuthentication: .basicAuthorizationHeaderAllowingEmptySecret
        )

        self.init(baseURLString: "https://oauth.reddit.com/api/v1/", requestInterceptor: interceptor)
    }

    public init(baseURLString: String, requestInterceptor: OAuth2Interceptor) {
        super.init(accountType: AccountStore.reddit, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
}

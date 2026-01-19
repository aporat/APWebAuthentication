import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

// MARK: - GitHubAPIClient

public final class GitHubAPIClient: OAuth2Client {

    // MARK: - Initialization

    public convenience init(auth: Auth2Authentication) {
        let interceptor = GitHubInterceptor(auth: auth)
        self.init(baseURLString: "https://api.github.com/", requestInterceptor: interceptor)
    }

    public init(baseURLString: String, requestInterceptor: GitHubInterceptor) {
        super.init(accountType: AccountStore.github, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
}

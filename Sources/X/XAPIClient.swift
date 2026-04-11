import Alamofire
import Foundation
@preconcurrency import SwiftyJSON

// MARK: - XAPIClient

public final class XAPIClient: OAuth2Client {

    // MARK: - Initialization

    public convenience init(auth: Auth2Authentication) {
        let interceptor = OAuth2Interceptor(auth: auth, tokenLocation: .authorizationHeader, refreshTokenURL: "https://api.x.com/2/oauth2/token")

        self.init(
            accountType: AccountStore.x,
            baseURLString: "https://api.x.com/2/",
            requestInterceptor: interceptor
        )
    }

    // MARK: - Error Handling

    override public func extractErrorMessage(from json: JSON?) -> String? {
        // Check errors array (Twitter API v2 format)
        if let message = json?["errors"][0]["message"].string {
            return message
        }

        // Check title field (problem detail format)
        if let message = json?["title"].string {
            return message
        }

        // Check detail field
        if let message = json?["detail"].string {
            return message
        }

        // Check simple error field (legacy format)
        if let message = json?["error"].string {
            return message
        }

        return super.extractErrorMessage(from: json)
    }
}

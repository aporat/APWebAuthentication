import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

// MARK: - TumblrAPIClient

@MainActor
public final class TumblrAPIClient: OAuth2Client {

    // MARK: - Initialization

    public required convenience init(auth: Auth2Authentication) {
        // Tumblr API v2 uses Bearer token in Authorization header
        let interceptor = OAuth2Interceptor(auth: auth, tokenLocation: .authorizationHeader)

        self.init(baseURLString: "https://api.tumblr.com/v2/", requestInterceptor: interceptor)
    }

    public init(baseURLString: String, requestInterceptor: OAuth2Interceptor) {
        super.init(accountType: AccountStore.tumblr, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
    
    // MARK: - Error Handling
    
    public override func extractErrorMessage(from json: JSON?) -> String? {
        // Check meta message field
        if let message = json?["meta"]["msg"].string {
            return message
        }
        
        // Check response errors array
        if let message = json?["response"]["errors"].array?.first?.string {
            return message
        }
        
        return super.extractErrorMessage(from: json)
    }
    
    public override func isSessionExpiredError(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        // Check for 401 status in Tumblr's meta field
        return super.isSessionExpiredError(response: response, json: json) || json?["meta"]["status"].int == 401
    }
}

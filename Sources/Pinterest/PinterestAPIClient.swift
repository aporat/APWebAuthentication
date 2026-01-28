import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

// MARK: - PinterestAPIClient

public final class PinterestAPIClient: OAuth2Client {

    // MARK: - Initialization

    public convenience init(auth: Auth2Authentication) {
        let interceptor = OAuth2Interceptor(auth: auth, tokenLocation: .authorizationHeader)

        self.init(baseURLString: "https://api.pinterest.com/v5/", requestInterceptor: interceptor)
    }

    public init(baseURLString: String, requestInterceptor: OAuth2Interceptor) {
        super.init(accountType: AccountStore.pinterest, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
    
    // MARK: - Error Handling
    
    public override func extractErrorMessage(from json: JSON?) -> String? {
        // Check modern API v5 error format
        if let message = json?["message"].string {
            return message
        }
        
        // Check legacy error formats for backward compatibility
        if let message = json?["resource_response"]["error"]["message"].string {
            return message
        }
        if let message = json?["error"]["message"].string {
            return message
        }
        
        return super.extractErrorMessage(from: json)
    }
}

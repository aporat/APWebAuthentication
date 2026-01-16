import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

// MARK: - PinterestAPIClient

public final class PinterestAPIClient: OAuth2Client {
    
    // MARK: - Properties
    
    public override var accountType: AccountType {
        AccountStore.pinterest
    }
    
    // MARK: - Initialization
    
    public convenience init(auth: Auth2Authentication) {
        let interceptor = OAuth2Interceptor(auth: auth)
        interceptor.tokenLocation = .authorizationHeader
        
        self.init(baseURLString: "https://api.pinterest.com/v5/", requestInterceptor: interceptor)
    }
    
    public override init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        // Validate that we are using an OAuth2 based interceptor
        guard requestInterceptor is OAuth2Interceptor else {
            fatalError("PinterestAPIClient requires an OAuth2Interceptor.")
        }
        
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
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

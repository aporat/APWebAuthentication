import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public final class FoursquareAPIClient: OAuth2Client {

    // MARK: - Initialization

    public convenience init(auth: Auth2Authentication) {
        let interceptor = FoursquareInterceptor(auth: auth)
        self.init(baseURLString: "https://api.foursquare.com/v2/", requestInterceptor: interceptor)
    }

    public init(baseURLString: String, requestInterceptor: FoursquareInterceptor) {
        super.init(accountType: AccountStore.foursquare, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }

    // MARK: - Error Handling
    
    public override func extractErrorMessage(from json: JSON?) -> String? {
        if let message = json?["meta"]["errorDetail"].string {
            return message
        }
        
        return super.extractErrorMessage(from: json)
    }
}

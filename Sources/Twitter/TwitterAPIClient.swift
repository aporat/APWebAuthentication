import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

// MARK: - TwitterAPIClient

public final class TwitterAPIClient: OAuth1Client {
    
    // MARK: - Properties
    
    public override var accountType: AccountType {
        AccountStore.twitter
    }
    
    // MARK: - Initialization
    
    public convenience init(consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        self.init(
            baseURLString: "https://api.twitter.com/2/",
            consumerKey: consumerKey,
            consumerSecret: consumerSecret,
            auth: auth
        )
    }
    
    // MARK: - Error Handling
    
    public override func extractErrorMessage(from json: JSON?) -> String? {
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

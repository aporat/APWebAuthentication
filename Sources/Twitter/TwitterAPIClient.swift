import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public final class TwitterAPIClient: OAuth1Client {
    
    public override var accountType: AccountType {
        AccountStore.twitter
    }
    
    public convenience init(consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        self.init(baseURLString: "https://api.twitter.com/2/", consumerKey: consumerKey, consumerSecret: consumerSecret, auth: auth)
    }
    
    public override func extractErrorMessage(from json: JSON?) -> String? {
        if let message = json?["errors"][0]["message"].string { // Common in v1.1 arrays
            return message
        }
        if let message = json?["title"].string { // Common in v2 top-level
            return message
        }
        if let message = json?["detail"].string { // Also seen in v2
            return message
        }
        if let message = json?["error"].string { // Seen in v1.1 simple errors
            return message
        }
        return super.extractErrorMessage(from: json)
    }
    
}

import Foundation
import Alamofire
@preconcurrency import SwiftyJSON
import AlamofireSwiftyJSON

public final class TumblrAPIClient: OAuth1Client {
    public convenience init(consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        self.init(baseURLString: "https://api.tumblr.com/v2/", consumerKey: consumerKey, consumerSecret: consumerSecret, auth: auth)
    }
    
    override public func extractErrorMessage(from json: JSON?) -> String? {
        if let message = json?["meta"]["msg"].string {
            return message
        }
        if let message = json?["response"]["errors"].array?.first?.string {
            return message
        }
        return super.extractErrorMessage(from: json)
    }
    
    override public func isSessionExpiredError(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        return super.isSessionExpiredError(response: response, json: json) || json?["meta"]["status"].int == 401
    }
}

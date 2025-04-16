import Foundation
import Alamofire

public final class TumblrAPIClient: OAuth1Client {
    public convenience init(consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        self.init(baseURLString: "https://api.tumblr.com/v2/", consumerKey: consumerKey, consumerSecret: consumerSecret, auth: auth)
    }
}

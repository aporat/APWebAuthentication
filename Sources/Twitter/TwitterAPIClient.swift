import Alamofire

public final class TwitterAPIClient: OAuth1Client {
    public convenience init(consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        self.init(baseURLString: "https://api.twitter.com/2/", consumerKey: consumerKey, consumerSecret: consumerSecret, auth: auth)
    }
}

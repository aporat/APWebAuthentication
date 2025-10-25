import Foundation
import Alamofire
@preconcurrency import SwiftyJSON
import AlamofireSwiftyJSON

public final class TumblrAPIClient: OAuth1Client {
    public convenience init(consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        self.init(baseURLString: "https://api.tumblr.com/v2/", consumerKey: consumerKey, consumerSecret: consumerSecret, auth: auth)
    }
    
    public override func generateError(from response: DataResponse<JSON, AFError>) -> APWebAuthenticationError {
            if let afError = response.error {
                if afError.isExplicitlyCancelledError {
                    return .canceled
                }
                if afError.isSessionTaskError {
                    return .connectionError(reason: "Please check your network connection.")
                }
            }
            
            if let json = response.value {
                let errorMessage = json["meta"]["msg"].string ??
                                   json["response"]["errors"].array?.first?.string
                
                if let message = errorMessage {
                    return .failed(reason: message)
                }
            }
            
            if let error = response.error {
                return .failed(reason: error.localizedDescription)
            }
            
            return .unknown
        }
}

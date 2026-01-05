import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

@MainActor
public class TikTokWebMobileAPIClient: AuthClient {
    
    // MARK: - Properties
    
    public override var accountType: AccountType {
        AccountStore.tiktok
    }
    
    fileprivate var interceptor: TikTokWebMobileInterceptor
    fileprivate let auth: TikTokWebAuthentication
    
    // MARK: - Initialization
    
    public convenience init(auth: TikTokWebAuthentication) {
        let interceptor = TikTokWebMobileInterceptor(auth: auth)
        self.init(baseURLString: "https://m.tiktok.com/", auth: auth, requestInterceptor: interceptor)
    }
    
    public init(baseURLString: String, auth: TikTokWebAuthentication, requestInterceptor: RequestInterceptor) {
        guard let customInterceptor = requestInterceptor as? TikTokWebMobileInterceptor else {
            fatalError("TikTokWebMobileAPIClient requires a TikTokWebMobileInterceptor.")
        }
        
        self.auth = auth
        self.interceptor = customInterceptor
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
    
    public override func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = super.makeSessionConfiguration()
        configuration.httpCookieStorage = auth.cookieStorage
        return configuration
    }
    
    // MARK: - Error Handling
    
    public override func extractErrorMessage(from json: JSON?) -> String? {
        if let message = json?["status_msg"].string {
            return message
        }
        if let message = json?["errMsg"].string {
            return message
        }
        if let message = json?["resource_response"]["error"]["message"].string {
            return message
        }
        if let message = json?["error"]["message"].string {
            return message
        }
        return super.extractErrorMessage(from: json)
    }
}

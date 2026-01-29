import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

@MainActor
public class TikTokWebAPIClient: AuthClient {

    // MARK: - Properties

    fileprivate var interceptor: TikTokWebInterceptor
    fileprivate let auth: TikTokWebAuthentication

    // MARK: - Initialization

    public convenience init(auth: TikTokWebAuthentication) {
        let interceptor = TikTokWebInterceptor(auth: auth)
        self.init(baseURLString: "https://www.tiktok.com/", auth: auth, requestInterceptor: interceptor)
    }

    public init(baseURLString: String, auth: TikTokWebAuthentication, requestInterceptor: TikTokWebInterceptor) {
        self.auth = auth
        self.interceptor = requestInterceptor
        super.init(accountType: AccountStore.tiktok, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
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

import Alamofire
import Foundation
@preconcurrency import SwiftyJSON

@MainActor
public class TikTokWebMobileAPIClient: AuthClient {

    // MARK: - Properties

    fileprivate var interceptor: TikTokWebMobileInterceptor
    fileprivate let auth: TikTokWebAuthentication

    // MARK: - Initialization

    public convenience init(auth: TikTokWebAuthentication) {
        let interceptor = TikTokWebMobileInterceptor(auth: auth)
        self.init(baseURLString: "https://m.tiktok.com/", auth: auth, requestInterceptor: interceptor)
    }

    public init(baseURLString: String, auth: TikTokWebAuthentication, requestInterceptor: TikTokWebMobileInterceptor) {
        self.auth = auth
        self.interceptor = requestInterceptor
        super.init(accountType: AccountStore.tiktok, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }

    override public func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = super.makeSessionConfiguration()
        configuration.httpCookieStorage = auth.cookieStorage
        return configuration
    }

    // MARK: - Error Handling

    override public func extractErrorMessage(from json: JSON?) -> String? {
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

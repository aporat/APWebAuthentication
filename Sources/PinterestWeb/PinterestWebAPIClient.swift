import Alamofire
import Foundation
@preconcurrency import SwiftyJSON

// MARK: - PinterestWebAPIClient

@MainActor
public final class PinterestWebAPIClient: AuthClient {

    // MARK: - Properties

    private var interceptor: PinterestWebInterceptor
    private let auth: PinterestWebAuthentication

    // MARK: - Initialization

    public required convenience init(auth: PinterestWebAuthentication) {
        let interceptor = PinterestWebInterceptor(auth: auth)
        self.init(baseURLString: "https://www.pinterest.com/", auth: auth, requestInterceptor: interceptor)
    }

    public init(baseURLString: String, auth: PinterestWebAuthentication, requestInterceptor: PinterestWebInterceptor) {
        self.auth = auth
        self.interceptor = requestInterceptor
        super.init(accountType: AccountStore.pinterest, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }

    // MARK: - Session Configuration

    override public func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = auth.cookieStorage
        return configuration
    }

    // MARK: - Error Handling

    override public func extractErrorMessage(from json: JSON?) -> String? {
        // Check nested error structure
        if let message = json?["resource_response"]["error"]["message"].string {
            return message
        }

        // Check simple error structure
        if let message = json?["error"]["message"].string {
            return message
        }

        return super.extractErrorMessage(from: json)
    }
}

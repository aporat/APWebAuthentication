import Foundation
import Alamofire
import SwiftyJSON

public final class TwitchAPIClient: AuthClient {
    fileprivate var requestAdapter: TwitchRequestAdapter

    public convenience init(auth: Auth2Authentication) {
        self.init(baseURLString: "https://api.twitch.tv/helix/", auth: auth)
    }

    public init(baseURLString: String, auth: Auth2Authentication) {
        requestAdapter = TwitchRequestAdapter(auth: auth)
        requestAdapter.tokenLocation = .authorizationHeader
        super.init(baseURLString: baseURLString)

        requestInterceptor = Interceptor(adapters: [requestAdapter], retriers: [requestRetrier])

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        sessionManager = makeSessionManager(configuration: configuration)
    }

    public func loadSettings(_ options: JSON?) {
        if let value = ProviderBrowserMode(options?["browser_mode"].string) {
            requestAdapter.auth.browserMode = value
        }

        if let value = options?["custom_user_agent"].string {
            requestAdapter.auth.customUserAgent = value
        }
    }
}

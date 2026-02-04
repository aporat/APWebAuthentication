import Alamofire
import Foundation

// MARK: - TwitchAPIClient

@MainActor
public final class TwitchAPIClient: OAuth2Client {

    // MARK: - Initialization

    public convenience init(auth: Auth2Authentication) {
        let interceptor = TwitchInterceptor(auth: auth, tokenLocation: .authorizationHeader)

        self.init(baseURLString: "https://api.twitch.tv/helix/", requestInterceptor: interceptor)
    }

    public init(baseURLString: String, requestInterceptor: TwitchInterceptor) {
        super.init(accountType: AccountStore.twitch, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }

}

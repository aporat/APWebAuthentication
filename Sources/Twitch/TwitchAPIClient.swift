import Alamofire
import Foundation

// MARK: - TwitchAPIClient

@MainActor
public final class TwitchAPIClient: OAuth2Client {

    // MARK: - Initialization

    /// Twitch's token endpoint, used for the refresh-token grant.
    public static let refreshTokenURL = "https://id.twitch.tv/oauth2/token"

    public convenience init(auth: Auth2Authentication) {
        // Twitch takes `client_id` / `client_secret` as form fields; public
        // clients omit the secret (https://dev.twitch.tv/docs/authentication/refresh-tokens/).
        let interceptor = TwitchInterceptor(
            auth: auth,
            tokenLocation: .authorizationHeader,
            refreshTokenURL: Self.refreshTokenURL,
            clientAuthentication: .requestBody
        )

        self.init(baseURLString: "https://api.twitch.tv/helix/", requestInterceptor: interceptor)
    }

    public init(baseURLString: String, requestInterceptor: TwitchInterceptor) {
        super.init(accountType: AccountStore.twitch, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }

}

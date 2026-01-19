import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

// MARK: - TwitchAPIClient

@MainActor
public final class TwitchAPIClient: OAuth2Client {

    // MARK: - Initialization

    public convenience init(auth: Auth2Authentication) {
        let interceptor = TwitchInterceptor(auth: auth)
        interceptor.tokenLocation = .authorizationHeader

        self.init(baseURLString: "https://api.twitch.tv/helix/", requestInterceptor: interceptor)
    }

    public init(baseURLString: String, requestInterceptor: TwitchInterceptor) {
        super.init(accountType: AccountStore.twitch, baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
    
    // MARK: - Configuration
    
    public override func loadSettings(_ options: JSON?) async {
        await super.loadSettings(options)
        
        // Load Twitch client ID from settings
        if let clientId = options?["client_id"].string {
            interceptor.auth.clientId = clientId
        }
    }
}

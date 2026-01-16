import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

// MARK: - TwitchAPIClient

@MainActor
public final class TwitchAPIClient: OAuth2Client {
    
    // MARK: - Properties
    
    public override var accountType: AccountType {
        AccountStore.twitch
    }
    
    // MARK: - Initialization
    
    public convenience init(auth: Auth2Authentication) {
        let interceptor = TwitchInterceptor(auth: auth)
        interceptor.tokenLocation = .authorizationHeader
        
        self.init(baseURLString: "https://api.twitch.tv/helix/", requestInterceptor: interceptor)
    }
    
    public override init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        // Validate that we are using a TwitchInterceptor
        guard requestInterceptor is TwitchInterceptor else {
            fatalError("TwitchAPIClient requires a TwitchInterceptor.")
        }
        
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
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

import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

@MainActor
public class TwitchAPIClient: OAuth2Client {
    
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
        // Validate specific type
        guard requestInterceptor is TwitchInterceptor else {
            fatalError("TwitchAPIClient requires a TwitchInterceptor.")
        }
        
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
    
    // MARK: - Configuration
    
    public override func loadSettings(_ options: JSON?) async {
        await super.loadSettings(options)
        
        if let clientId = options?["client_id"].string {
            interceptor.auth.clientId = clientId
        }
    }
}

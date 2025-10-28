import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public class TwitchAPIClient: AuthClient {
    
    public override var accountType: AccountType {
        AccountStore.twitch
    }
    
    fileprivate var requestAdapter: TwitchRequestAdapter
    
    public init(auth: Auth2Authentication) {
        requestAdapter = TwitchRequestAdapter(auth: auth)
        super.init(baseURLString: "https://api.twitch.tv/helix/")
        requestInterceptor = Interceptor(adapters: [requestAdapter], retriers: [requestRetrier])
        
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        sessionManager = makeSessionManager(configuration: configuration)
    }
    
    public func loadSettings(_ options: JSON?) {
        if let clientId = options?["client_id"].string {
            requestAdapter.auth.clientId = clientId
        }
    }

}

import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

@MainActor
public class TwitchAPIClient: AuthClient {
    
    public override var accountType: AccountType {
        AccountStore.twitch
    }
    
    fileprivate var requestAdapter: TwitchRequestAdapter
    
    public convenience init(auth: Auth2Authentication) {
        let requestAdapter = TwitchRequestAdapter(auth: auth)
        requestAdapter.tokenLocation = .authorizationHeader
        let interceptor = Interceptor(adapters: [requestAdapter])
        
        self.init(baseURLString: "https://api.twitch.tv/helix/", requestInterceptor: interceptor)
    }
    
    public override init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        guard let interceptor = requestInterceptor as? Interceptor,
              let adapter = interceptor.adapters.first as? TwitchRequestAdapter
        else {
            fatalError("Failed to extract RequestInterceptor from requestInterceptor.")
        }
        
        self.requestAdapter = adapter
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
    
    public func loadSettings(_ options: JSON?) {
        if let clientId = options?["client_id"].string {
            requestAdapter.auth.clientId = clientId
        }
    }
    
}

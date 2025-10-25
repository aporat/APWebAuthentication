import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public class TwitchAPIClient: AuthClient {
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

    public override func generateError(from response: DataResponse<JSON, AFError>) -> APWebAuthenticationError {
        if let afError = response.error {
            if afError.isExplicitlyCancelledError {
                return .canceled
            }
            if afError.isSessionTaskError {
                return .connectionError(reason: "Please check your network connection.")
            }
        }
        
        if let json = response.value {
            let errorMessage = json["message"].string ?? json["error_message"].string
            
            if let message = errorMessage {
                return .failed(reason: message)
            }
        }
        
        if let error = response.error {
            return .failed(reason: error.localizedDescription)
        }
        
        return .unknown
    }
}

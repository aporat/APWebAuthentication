import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public final class PinterestAPIClient: AuthClient {
    fileprivate var requestAdapter: OAuth2RequestAdapter
    
    public required convenience init(auth: Auth2Authentication) {
        self.init(baseURLString: "https://api.pinterest.com/v5/", auth: auth)
    }
    
    public init(baseURLString: String, auth: Auth2Authentication) {
        requestAdapter = OAuth2RequestAdapter(auth: auth)
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
            let errorMessage = json["meta"]["error_message"].string ??
            json["error_message"].string ??
            json["message"].string
            
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


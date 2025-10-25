import Foundation
import Alamofire
@preconcurrency import SwiftyJSON

public class TikTokWebAPIClient: AuthClient {
    fileprivate var requestAdapter: TikTokWebRequestAdapter
    
    public init(auth: TikTokWebAuthentication) {
        requestAdapter = TikTokWebRequestAdapter(auth: auth)
        super.init(baseURLString: "https://www.tiktok.com/")
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
            let errorMessage = json["resource_response"]["error"]["message"].string ??
                               json["error"]["message"].string ??
                               json["status_msg"].string ??
                               json["errMsg"].string
            
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

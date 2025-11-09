import Foundation
import Alamofire
import SwiftyJSON

open class OAuth2Client: AuthClient {
    var requestAdapter: OAuth2RequestAdapter

    public convenience init(baseURLString: String, auth: Auth2Authentication) {
        let requestAdapter = OAuth2RequestAdapter(auth: auth)
        let retrier = AuthClientRequestRetrier()
        let interceptor = Interceptor(adapters: [requestAdapter], retriers: [retrier])
        
        self.init(baseURLString: baseURLString, requestInterceptor: interceptor)
        
        self.requestAdapter = requestAdapter
        self.requestRetrier = retrier
    }
    
    public override init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        guard let interceptor = requestInterceptor as? Interceptor,
              let adapter = interceptor.adapters.first as? OAuth2RequestAdapter
        else {
            fatalError("Failed to extract RequestInterceptor from requestInterceptor.")
        }
        
        self.requestAdapter = adapter
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }

    public func loadSettings(_ options: JSON?) {
        if let value = ProviderBrowserMode(options?["browser_mode"].string) {
            requestAdapter.auth.browserMode = value
        }

        if let value = options?["custom_user_agent"].string {
            requestAdapter.auth.customUserAgent = value
        }
    }
}

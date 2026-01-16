import Foundation
import Alamofire

// MARK: - PinterestWebHTMLAPIClient

@MainActor
public final class PinterestWebHTMLAPIClient: AuthClient {
    
    // MARK: - Properties
    
    public override var accountType: AccountType {
        AccountStore.pinterest
    }
    
    private var interceptor: PinterestWebHTMLInterceptor
    private let auth: PinterestWebAuthentication
    
    // MARK: - Initialization
    
    public required convenience init(auth: PinterestWebAuthentication) {
        let interceptor = PinterestWebHTMLInterceptor(auth: auth)
        self.init(baseURLString: "https://www.pinterest.com/", auth: auth, requestInterceptor: interceptor)
    }
    
    public init(baseURLString: String, auth: PinterestWebAuthentication, requestInterceptor: RequestInterceptor) {
        guard let customInterceptor = requestInterceptor as? PinterestWebHTMLInterceptor else {
            fatalError("PinterestWebHTMLAPIClient requires a PinterestWebHTMLInterceptor.")
        }
        
        self.auth = auth
        self.interceptor = customInterceptor
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
    
    // MARK: - Session Configuration
    
    public override func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = auth.cookieStorage
        return configuration
    }
}

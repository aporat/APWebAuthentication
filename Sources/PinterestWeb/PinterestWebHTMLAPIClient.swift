import Foundation
import Alamofire

@MainActor
public final class PinterestWebHTMLAPIClient: AuthClient {
    
    public override var accountType: AccountType {
        AccountStore.pinterest
    }
    
    fileprivate var requestAdapter: PinterestWebHTMLRequestAdapter
    fileprivate let auth: PinterestWebAuthentication
    
    public required convenience init(auth: PinterestWebAuthentication) {
        let requestAdapter = PinterestWebHTMLRequestAdapter(auth: auth)
        let interceptor = Interceptor(adapters: [requestAdapter])
        
        self.init(baseURLString: "https://www.pinterest.com/", auth: auth, requestInterceptor: interceptor)
    }
    
    public init(baseURLString: String, auth: PinterestWebAuthentication, requestInterceptor: RequestInterceptor) {
        self.auth = auth
        self.requestAdapter = (requestInterceptor as! Interceptor).adapters.first as! PinterestWebHTMLRequestAdapter
        super.init(baseURLString: baseURLString, requestInterceptor: requestInterceptor)
    }
    
    public override func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = auth.cookieStorage
        return configuration
    }
}

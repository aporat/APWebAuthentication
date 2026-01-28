import Foundation
import Alamofire

public final class PinterestWebHTMLInterceptor: RequestInterceptor, Sendable {
    
    @MainActor
    var auth: PinterestWebAuthentication
    
    @MainActor
    public init(auth: PinterestWebAuthentication) {
        self.auth = auth
    }
    
    // MARK: - RequestAdapter
    
    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        
        Task {
            var urlRequest = urlRequest
            
            if let currentUserAgent = await auth.userAgent, !currentUserAgent.isEmpty {
                urlRequest.headers.add(.userAgent(currentUserAgent))
            }
            
            urlRequest.headers.add(HTTPHeader(name: "Referer", value: "https://www.pinterest.com"))
            urlRequest.headers.add(HTTPHeader(name: "Origin", value: "https://www.pinterest.com"))
            
            let locale = await auth.localeWebIdentifier
            urlRequest.headers.add(.acceptLanguage(locale))
            
            // Standard HTML/Browser accept headers
            urlRequest.headers.add(.accept("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"))
            urlRequest.headers.add(.acceptEncoding("gzip, deflate, sdch, br"))
            urlRequest.headers.add(HTTPHeader(name: "Connection", value: "keep-alive"))
            
            completion(.success(urlRequest))
        }
    }
}

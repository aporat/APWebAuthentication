import Alamofire
import UIKit

open class OAuth2Client: AuthClient {
    var requestAdapter: OAuth2RequestAdapter

    public init(baseURLString: String, auth: Auth2Authentication) {
        requestAdapter = OAuth2RequestAdapter(auth: auth)
        super.init(baseURLString: baseURLString)

        requestInterceptor = Interceptor(adapters: [requestAdapter], retriers: [requestRetrier])

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        sessionManager = makeSessionManager(configuration: configuration)
    }
}

import Foundation
import Alamofire
import SwiftyJSON
import AlamofireSwiftyJSON

public class GitHubAPIClient: AuthClient {
    fileprivate var requestAdapter: GitHubRequestAdapter
    
    public convenience init(auth: Auth2Authentication) {
        self.init(baseURLString: "https://api.github.com/", auth: auth)
    }
    
    public init(baseURLString: String, auth: Auth2Authentication) {
        requestAdapter = GitHubRequestAdapter(auth: auth)
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
    
    public func perform(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters = Parameters(),
        encoding: any ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) async throws(APWebAuthenticationError) -> JSON {
        let url = try url(for: path)
        
        let dataTask = sessionManager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
            .validate()
            .serializingResponse(using: SwiftyJSONResponseSerializer())
        
        let response = await dataTask.response
        
        switch response.result {
        case .success(let value):
            return value
        case .failure:
            throw generateError(from: response)
        }
    }
    
    /// Performs a network request and returns both the JSON and the full HTTPURLResponse.
    public func performWithResponse(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters = Parameters(),
        encoding: any ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) async throws(APWebAuthenticationError) -> (json: JSON, response: HTTPURLResponse) {
        let url = try url(for: path)
        
        let dataTask = sessionManager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
            .validate()
            .serializingResponse(using: SwiftyJSONResponseSerializer())
        
        let response = await dataTask.response
        
        guard let httpResponse = response.response else {
            throw generateError(from: response)
        }
        
        switch response.result {
        case .success(let value):
            return (json: value, response: httpResponse)
        case .failure:
            throw generateError(from: response)
        }
    }
    
    public func getStatusCode(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters = Parameters(),
        encoding: any ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) async throws(APWebAuthenticationError) -> Int {
        let url = try url(for: path)
        
        let dataTask = sessionManager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
        let response = await dataTask.response
        
        guard let statusCode = response?.statusCode else {
            throw APWebAuthenticationError.unknown
        }
        
        return statusCode
    }
    
    private func generateError(from response: DataResponse<JSON, AFError>) -> APWebAuthenticationError {
        if let afError = response.error {
            if afError.isExplicitlyCancelledError {
                return .canceled
            }
            if afError.isSessionTaskError {
                return .connectionError(reason: "Please check your network connection.")
            }
        }
        
        if let json = response.value {
            let errorMessage = json["message"].string ??
            json["meta"]["error_message"].string ??
            json["error"]["message"].string ??
            json["error_message"].string
            
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

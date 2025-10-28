import Foundation
@preconcurrency import Alamofire
import CryptoKit
@preconcurrency import SwiftyJSON
import AlamofireSwiftyJSON
import HTTPStatusCodes

public enum ProviderAuthMode: String {
    case `private`
    case explicit
    case implicit
    case web
    case browser
    case app
    
    public init?(_ rawValue: String?) {
        guard let currentRawValue = rawValue, let value = ProviderAuthMode(rawValue: currentRawValue) else {
            return nil
        }
        self = value
    }
}

public extension AuthClient {
    static let didRateLimitReached = Notification.Name(rawValue: "apwebauthentication.client.ratelimit")
    static let didRateLimitSessionExpired = Notification.Name(rawValue: "apwebauthentication.client.sessionexpired")
    static let didRateLimitCancelled = Notification.Name(rawValue: "apwebauthentication.client.ratelimit.cancelled")
}

open class AuthClient {
    public var baseURLString: String
    open var sessionManager: Session!
    open var requestRetrier = AuthClientRequestRetrier()
    open var requestInterceptor: RequestInterceptor!
    
    open var accountType: AccountType {
        fatalError("Subclasses must override the accountType property.")
    }
    
    open func makeSessionManager(configuration: URLSessionConfiguration) -> Session {
        Session(configuration: configuration, delegate: SessionDelegate(), interceptor: requestInterceptor)
    }
    
    public var isReloadingCancelled: Bool = false {
        didSet {
            requestRetrier.isReloadingCancelled = isReloadingCancelled
        }
    }
    
    public var shouldRetryRateLimit: Bool = false {
        didSet {
            requestRetrier.shouldRetryRateLimit = shouldRetryRateLimit
        }
    }
    
    public var shouldAlwaysShowLoginAgain: Bool = false {
        didSet {
            requestRetrier.shouldAlwaysShowLoginAgain = shouldAlwaysShowLoginAgain
        }
    }
    
    public init(baseURLString: String) {
        self.baseURLString = baseURLString
    }
    
    public func request(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters = Parameters(),
        encoding: ParameterEncoding = URLEncoding.default,
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
    public func requestWithResponse(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters = Parameters(),
        encoding: ParameterEncoding = URLEncoding.default,
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
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) async throws(APWebAuthenticationError) -> Int {
        let url = try url(for: path)
        
        let dataTask = sessionManager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
            .validate(statusCode: 200..<600) // Validate broader range
            .serializingData() // Use serializingData
        
        let response = await dataTask.response
        
        guard let httpResponse = response.response else {
            if let afError = response.error {
                let dummyDataResponse = DataResponse<JSON, AFError>(
                    request: response.request,
                    response: nil,
                    data: response.data,
                    metrics: response.metrics,
                    serializationDuration: response.serializationDuration,
                    result: .failure(afError)
                )
                throw generateError(from: dummyDataResponse)
            } else {
                throw APWebAuthenticationError.unknown
            }
        }
        return httpResponse.statusCode
    }
    
    
    open func generateError(from response: DataResponse<JSON, AFError>) -> APWebAuthenticationError {
        
        // 1. Check for Cancellation/Connection Errors
        if let afError = response.error {
            if afError.isExplicitlyCancelledError { return .canceled }
            if afError.isSessionTaskError {
                let errorJson = parseJson(from: response)
                let reason = String(format: NSLocalizedString("Check your network connection. %@ could also be down.", comment: ""), accountType.description)
                return .connectionError(reason: reason, responseJSON: errorJson)
            }
        }
        
        // 2. Parse JSON & Extract Messages
        let json = parseJson(from: response)
        let jsonErrorMessage = extractErrorMessage(from: json) // Calls potentially overridden method
        let underlyingErrorMessage = extractUnderlyingErrorMessage(from: response)
        let reason = jsonErrorMessage ?? underlyingErrorMessage // Best available message
        
        // 3. Check Specific Error Conditions using Overridable Helpers
        if isServerError(response: response, json: json) {
            let serverReason = underlyingErrorMessage ?? String(format: "Internal server error. %@ might be down.", accountType.description)
            return .serverError(reason: serverReason, responseJSON: json)
        }
        
        if isCheckpointRequired(response: response, json: json) {
            let checkpointReason = jsonErrorMessage ?? "Checkpoint or feedback required."
            return .checkPointRequired(content: json)
        }
        
        if isRateLimitError(response: response, json: json) {
            return .rateLimit(reason: reason, responseJSON: json)
        }
        
        if isSessionExpiredError(response: response, json: json) {
            return .sessionExpired(reason: reason, responseJSON: json)
        }
        
        // 4. Fallback using Parsed JSON Message
        if let message = jsonErrorMessage {
            return .failed(reason: message, responseJSON: json)
        }
        
        // 5. Fallback using Underlying AFError Message
        if let message = underlyingErrorMessage {
            return .failed(reason: message, responseJSON: json)
        }
        
        // 6. Final Fallback
        return .failed(reason: "Unknown error.", responseJSON: json)
    }
    
    // --- Overridable Helper Functions ---
    
    /// Checks if the response indicates a server-side error (typically 5xx).
    open func isServerError(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        return response.response?.statusCodeValue?.isServerError ?? false
    }
    
    /// Checks if the response indicates a rate limit error (typically 429).
    open func isRateLimitError(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        return response.response?.statusCodeValue == .tooManyRequests
    }
    
    /// Checks if the response indicates a session/authentication error (typically 401).
    open func isSessionExpiredError(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        return response.response?.statusCodeValue == .unauthorized
    }
    
    open func isCheckpointRequired(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        return false
    }
    
    /// Subclasses should override this to handle service-specific JSON structures.
    open func extractErrorMessage(from json: JSON?) -> String? {
        // Default implementation checks common keys sequentially
        if let message = json?["message"].string {
            return message
        }
        if let message = json?["meta"]["error_message"].string {
            return message
        }
        if let message = json?["error"]["message"].string {
            return message
        }
        if let message = json?["error_message"].string {
            return message
        }
        if let message = json?["feedback_message"].string {
            return message
        }
        if let message = json?["error_title"].string {
            return message
        }
        // If none of the keys yielded a string, return nil
        return nil
    }
    
    // --- Internal Helper Functions ---
    /// Attempts to get JSON from response.value or manually parses response.data.
    internal func parseJson(from response: DataResponse<JSON, AFError>) -> JSON? {
        if let jsonValue = response.value {
            return jsonValue
        } else if let data = response.data {
            return try? JSON(data: data)
        }
        return nil
    }
    
    /// Extracts the localized description from the underlying AFError, if present.
    internal func extractUnderlyingErrorMessage(from response: DataResponse<JSON, AFError>) -> String? {
        if let error = response.error?.asAFError?.underlyingError?.localizedDescription {
            return error
        } else if let error = response.error?.localizedDescription {
            return error
        }
        return nil
    }
    
    public func cancelAllRequests() {
        isReloadingCancelled = true
        sessionManager.session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }
    
    open func url(for path: String) throws(APWebAuthenticationError) -> URL {
        if let absoluteURL = URL(string: path), absoluteURL.scheme != nil {
            return absoluteURL
        } else {
            guard let baseURL = URL(string: baseURLString)?.appendingPathComponent(path) else {
                throw APWebAuthenticationError.unknown
            }
            return baseURL
        }
    }
}

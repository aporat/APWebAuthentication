import Foundation
@preconcurrency import Alamofire
import CryptoKit
@preconcurrency import SwiftyJSON
import HTTPStatusCodes

public extension AuthClient {
    static let didRateLimitReached = Notification.Name(rawValue: "apwebauthentication.client.ratelimit")
    static let didRateLimitSessionExpired = Notification.Name(rawValue: "apwebauthentication.client.sessionexpired")
    static let didRateLimitCancelled = Notification.Name(rawValue: "apwebauthentication.client.ratelimit.cancelled")
}

@MainActor
open class AuthClient {
    public var baseURLString: String
    
    open lazy var sessionManager: Session = self.makeSessionManager(
        configuration: self.makeSessionConfiguration()
    )
    
    public let requestInterceptor: RequestInterceptor
    
    open var accountType: AccountType {
        fatalError("Subclasses must override the accountType property.")
    }
    
    open func makeSessionManager(configuration: URLSessionConfiguration) -> Session {
        Session(configuration: configuration, delegate: SessionDelegate(), interceptor: requestInterceptor)
    }
    
    open func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        return configuration
    }
    
    public var isReloadingCancelled: Bool = false
    
    public var shouldAlwaysShowLoginAgain: Bool = false
    
    public init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        self.baseURLString = baseURLString
        self.requestInterceptor = requestInterceptor
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
            .serializingDecodable(JSON.self)
        
        let response = await dataTask.response
        
        switch response.result {
        case .success(let value):
            return value
        case .failure:
            throw generateError(from: response)
        }
    }
    
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
            .serializingDecodable(JSON.self)
        
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
            .validate(statusCode: 200..<600)
            .serializingDecodable(JSON.self)
        
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
        
        let json = parseJson(from: response)
        
        if let afError = response.error {
            if afError.isExplicitlyCancelledError { return .canceled }
            if afError.isSessionTaskError {
                let errorJson = parseJson(from: response)
                let reason = String(format: NSLocalizedString("Check your network connection. %@ could also be down.", comment: ""), accountType.description)
                
                return .connectionError(reason: reason, responseJSON: errorJson)
            }
        }
        
        let jsonErrorMessage = extractErrorMessage(from: json)
        let underlyingErrorMessage = extractUnderlyingErrorMessage(from: response)
        let reason = jsonErrorMessage ?? underlyingErrorMessage
        
        if isServerError(response: response, json: json) {
            let serverReason = underlyingErrorMessage ?? String(format: "Internal server error. %@ might be down.", accountType.description)
            return .serverError(reason: serverReason, responseJSON: json)
        }
        
        if isCheckpointRequired(response: response, json: json) {
            return .checkPointRequired(responseJSON: json)
        }
        
        if isRateLimitError(response: response, json: json) {
            return .rateLimit(reason: reason, responseJSON: json)
        }
        
        if isSessionExpiredError(response: response, json: json) {
            return .sessionExpired(reason: reason, responseJSON: json)
        }
        
        if let message = jsonErrorMessage {
            return .failed(reason: message, responseJSON: json)
        }
        
        if let message = underlyingErrorMessage {
            return .failed(reason: message, responseJSON: json)
        }
        
        return .failed(reason: "Unknown error.", responseJSON: json)
    }
    
    open func isServerError(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        return response.response?.statusCodeValue?.isServerError ?? false
    }
    
    open func isRateLimitError(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        return response.response?.statusCodeValue == .tooManyRequests
    }
    
    open func isSessionExpiredError(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        return response.response?.statusCodeValue == .unauthorized
    }
    
    open func isCheckpointRequired(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        return false
    }
    
    open func extractErrorMessage(from json: JSON?) -> String? {
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
        return nil
    }
    
    internal func parseJson(from response: DataResponse<JSON, AFError>) -> JSON? {
        if let jsonValue = response.value {
            return jsonValue
        } else if let data = response.data {
            return try? JSON(data: data)
        }
        return nil
    }
    
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

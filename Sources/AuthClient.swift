import Foundation
@preconcurrency import Alamofire
import CryptoKit
@preconcurrency import SwiftyJSON
import HTTPStatusCodes

// MARK: - Notifications

/// Notifications posted by `AuthClient` for various authentication events.
public extension AuthClient {
    
    /// Posted when a rate limit error is encountered.
    ///
    /// Posted when a session expires and needs re-authentication.
    ///
    /// Listen for this notification to redirect users to login screens.
    static let didSessionExpired = Notification.Name(rawValue: "apwebauthentication.client.sessionexpired")
    
    /// Posted when rate limit retry is cancelled by the user.
}

// MARK: - Auth Client

/// Base class for authenticated HTTP clients.
///
/// `AuthClient` provides a foundation for building API clients that require authentication.
/// It handles:
/// - Request execution with automatic error handling
/// - Session management and configuration
/// - Error parsing and classification
/// - Request cancellation
/// - URL construction
///
/// **Subclassing:**
/// Subclasses must override `accountType` to specify the platform they target.
/// They can also override error handling methods to customize behavior:
/// - `isServerError()` - Custom server error detection
/// - `isRateLimitError()` - Custom rate limit detection
/// - `isSessionExpiredError()` - Custom session expiration detection
/// - `isCheckpointRequired()` - Custom checkpoint detection
/// - `extractErrorMessage()` - Custom error message extraction
///
/// **Example:**
/// ```swift
/// class MyAPIClient: AuthClient {
///     override var accountType: AccountType {
///         AccountStore.myPlatform
///     }
///
///     func fetchUser() async throws {
///         let json = try await request("/user")
///         // Process response...
///     }
/// }
/// ```
///
/// - Note: All operations must be performed on the main actor.
@MainActor
open class AuthClient {
    
    // MARK: - Properties
    
    /// The base URL for all API requests.
    ///
    /// Requests with relative paths are resolved against this base URL.
    /// Absolute URLs bypass the base URL.
    public var baseURLString: String
    
    /// The Alamofire session manager for executing requests.
    ///
    /// Lazily initialized with the configuration from `makeSessionConfiguration()`
    /// and the interceptor provided during initialization.
    open lazy var sessionManager: Session = makeSessionManager(
        configuration: makeSessionConfiguration()
    )
    
    /// The request interceptor for adding authentication headers and handling retries.
    ///
    /// The interceptor is typically an OAuth1Interceptor, OAuth2Interceptor, or custom subclass
    /// that adds platform-specific authentication.
    public let requestInterceptor: RequestInterceptor
    
    /// The account type/platform this client targets.
    ///
    /// Subclasses **must** override this property to specify their platform.
    ///
    /// **Example:**
    /// ```swift
    /// override var accountType: AccountType {
    ///     AccountStore.instagram
    /// }
    /// ```
    ///
    /// - Important: Failing to override this property will cause a fatal error.
    open var accountType: AccountType {
        fatalError("Subclasses must override the accountType property.")
    }
    
    /// Whether request reloading has been cancelled by the user.
    ///
    /// Set this to `true` to indicate that automatic retry attempts should stop.
    public var isReloadingCancelled: Bool = false
    
    /// Whether to always show the login screen again after authentication errors.
    ///
    /// When `true`, authentication errors will always prompt for login
    /// rather than attempting automatic token refresh.
    public var shouldAlwaysShowLoginAgain: Bool = false
    
    // MARK: - Initialization
    
    /// Creates a new auth client with the specified base URL and request interceptor.
    ///
    /// - Parameters:
    ///   - baseURLString: The base URL for all API requests
    ///   - requestInterceptor: The interceptor for adding authentication and handling retries
    public init(baseURLString: String, requestInterceptor: RequestInterceptor) {
        self.baseURLString = baseURLString
        self.requestInterceptor = requestInterceptor
    }
    
    // MARK: - Session Configuration
    
    /// Creates the Alamofire session manager with the given configuration.
    ///
    /// Override this method to customize session creation, such as adding
    /// custom session delegates or event monitors.
    ///
    /// - Parameter configuration: The URL session configuration to use
    /// - Returns: A configured Alamofire session
    open func makeSessionManager(configuration: URLSessionConfiguration) -> Session {
        print("🏗️ AuthClient.makeSessionManager() called for \(type(of: self))")
        print("   Interceptor: \(type(of: requestInterceptor))")
        print("   Cookie storage: \(configuration.httpCookieStorage?.cookies?.count ?? 0) cookies")
        
        let session = Session(
            configuration: configuration,
            delegate: SessionDelegate(),
            interceptor: requestInterceptor
        )
        
        print("✅ Session created with interceptor: \(session.interceptor != nil)")
        return session
    }
    
    /// Creates the URL session configuration for the client.
    ///
    /// The default implementation creates an ephemeral configuration with cookies disabled.
    /// Override this method to customize configuration options like:
    /// - Cookie storage
    /// - Cache policy
    /// - Timeout intervals
    /// - Connection limits
    ///
    /// **Example:**
    /// ```swift
    /// override func makeSessionConfiguration() -> URLSessionConfiguration {
    ///     let config = super.makeSessionConfiguration()
    ///     config.timeoutIntervalForRequest = 30
    ///     return config
    /// }
    /// ```
    ///
    /// - Returns: A configured URLSessionConfiguration
    open func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        return configuration
    }
    
    // MARK: - API Requests
    
    /// Executes an HTTP request and returns the JSON response.
    ///
    /// This is the primary method for making API requests. It automatically:
    /// - Validates the response status code
    /// - Parses JSON from the response
    /// - Generates appropriate errors on failure
    ///
    /// **Example:**
    /// ```swift
    /// let json = try await request("/users/me")
    /// let username = json["username"].stringValue
    /// ```
    ///
    /// - Parameters:
    ///   - path: The API endpoint path (relative or absolute URL)
    ///   - method: The HTTP method (default: GET)
    ///   - parameters: Request parameters (query params for GET, body for POST)
    ///   - encoding: How to encode parameters (default: URL encoding)
    ///   - headers: Optional HTTP headers to add to the request
    ///
    /// - Returns: The parsed JSON response
    /// - Throws: `APWebAuthenticationError` on failure
    public func request(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters = Parameters(),
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) async throws(APWebAuthenticationError) -> JSON {
        let url = try url(for: path)
        
        let dataTask = sessionManager
            .request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
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
    
    /// Executes an HTTP request and returns both the JSON response and HTTP response.
    ///
    /// Use this method when you need access to HTTP headers, status codes, or other
    /// response metadata in addition to the JSON body.
    ///
    /// **Example:**
    /// ```swift
    /// let (json, response) = try await requestWithResponse("/users/me")
    /// print("Status: \(response.statusCode)")
    /// print("Headers: \(response.allHeaderFields)")
    /// ```
    ///
    /// - Parameters:
    ///   - path: The API endpoint path (relative or absolute URL)
    ///   - method: The HTTP method (default: GET)
    ///   - parameters: Request parameters (query params for GET, body for POST)
    ///   - encoding: How to encode parameters (default: URL encoding)
    ///   - headers: Optional HTTP headers to add to the request
    ///
    /// - Returns: A tuple containing the JSON response and HTTP response
    /// - Throws: `APWebAuthenticationError` on failure
    public func requestWithResponse(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters = Parameters(),
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) async throws(APWebAuthenticationError) -> (json: JSON, response: HTTPURLResponse) {
        let url = try url(for: path)
        
        let dataTask = sessionManager
            .request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
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
    
    /// Executes an HTTP request and returns only the status code.
    ///
    /// Useful for testing endpoint availability or checking if resources exist
    /// without needing to parse the response body.
    ///
    /// **Example:**
    /// ```swift
    /// let statusCode = try await getStatusCode("/health")
    /// if statusCode == 200 {
    ///     print("Service is healthy")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The API endpoint path (relative or absolute URL)
    ///   - method: The HTTP method (default: GET)
    ///   - parameters: Request parameters (query params for GET, body for POST)
    ///   - encoding: How to encode parameters (default: URL encoding)
    ///   - headers: Optional HTTP headers to add to the request
    ///
    /// - Returns: The HTTP status code (200-599)
    /// - Throws: `APWebAuthenticationError` if the request fails at the network level
    public func getStatusCode(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters = Parameters(),
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) async throws(APWebAuthenticationError) -> Int {
        let url = try url(for: path)
        
        let dataTask = sessionManager
            .request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
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
    
    // MARK: - Error Generation
    
    /// Generates an appropriate `APWebAuthenticationError` from an Alamofire response.
    ///
    /// This method analyzes the response and classifies the error into specific categories:
    /// 1. Checks for explicitly cancelled requests
    /// 2. Checks for connection/network errors
    /// 3. Checks for server errors (5xx)
    /// 4. Checks for checkpoints/security checks
    /// 5. Checks for rate limiting
    /// 6. Checks for session expiration
    /// 7. Falls back to generic failure with extracted error message
    ///
    /// Subclasses can override the classification methods to customize error handling.
    ///
    /// - Parameter response: The Alamofire data response to analyze
    /// - Returns: An appropriate `APWebAuthenticationError`
    open func generateError(from response: DataResponse<JSON, AFError>) -> APWebAuthenticationError {
        let json = parseJson(from: response)
        
        // Check for explicitly cancelled requests
        if let afError = response.error {
            if afError.isExplicitlyCancelledError {
                return .canceled
            }
            
            // Check for network/connection errors
            if afError.isSessionTaskError {
                let errorJson = parseJson(from: response)
                let reason = String(
                    format: NSLocalizedString(
                        "Check your network connection. %@ could also be down.",
                        comment: ""
                    ),
                    accountType.description
                )
                return .connectionError(reason: reason, responseJSON: errorJson)
            }
        }
        
        // Extract error messages
        let jsonErrorMessage = extractErrorMessage(from: json)
        let underlyingErrorMessage = extractUnderlyingErrorMessage(from: response)
        let reason = jsonErrorMessage ?? underlyingErrorMessage
        
        // Check for specific error types
        if isServerError(response: response, json: json) {
            let serverReason = underlyingErrorMessage ?? String(
                format: "Internal server error. %@ might be down.",
                accountType.description
            )
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
        
        // Generic failures with error messages
        if let message = jsonErrorMessage {
            return .failed(reason: message, responseJSON: json)
        }
        
        if let message = underlyingErrorMessage {
            return .failed(reason: message, responseJSON: json)
        }
        
        return .failed(reason: "Unknown error.", responseJSON: json)
    }
    // MARK: - Error Classification
    
    /// Determines if a response represents a server error (5xx status code).
    ///
    /// The default implementation checks for HTTP status codes in the 500-599 range.
    /// Override this method to add custom server error detection logic.
    ///
    /// - Parameters:
    ///   - response: The Alamofire data response
    ///   - json: The parsed JSON response (if available)
    ///
    /// - Returns: `true` if this is a server error, `false` otherwise
    open func isServerError(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        response.response?.statusCodeValue?.isServerError ?? false
    }
    
    /// Determines if a response represents a rate limit error (429 status code).
    ///
    /// The default implementation checks for HTTP 429 Too Many Requests.
    /// Override this method to add custom rate limit detection (e.g., checking JSON fields).
    ///
    /// - Parameters:
    ///   - response: The Alamofire data response
    ///   - json: The parsed JSON response (if available)
    ///
    /// - Returns: `true` if this is a rate limit error, `false` otherwise
    open func isRateLimitError(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        response.response?.statusCodeValue == .tooManyRequests
    }
    
    /// Determines if a response represents a session expiration (401 status code).
    ///
    /// The default implementation checks for HTTP 401 Unauthorized.
    /// Override this method to add custom session expiration detection.
    ///
    /// - Parameters:
    ///   - response: The Alamofire data response
    ///   - json: The parsed JSON response (if available)
    ///
    /// - Returns: `true` if the session has expired, `false` otherwise
    open func isSessionExpiredError(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        response.response?.statusCodeValue == .unauthorized
    }
    
    /// Determines if a response requires a security checkpoint.
    ///
    /// The default implementation always returns `false`. Subclasses should override
    /// this method to detect platform-specific checkpoint requirements.
    ///
    /// **Example:**
    /// ```swift
    /// override func isCheckpointRequired(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
    ///     json?["checkpoint_required"].boolValue ?? false
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - response: The Alamofire data response
    ///   - json: The parsed JSON response (if available)
    ///
    /// - Returns: `true` if a checkpoint is required, `false` otherwise
    open func isCheckpointRequired(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        false
    }
    
    /// Extracts an error message from the JSON response.
    ///
    /// The default implementation checks multiple common JSON fields:
    /// - `message`
    /// - `meta.error_message`
    /// - `error.message`
    /// - `error_message`
    /// - `feedback_message`
    /// - `error_title`
    ///
    /// Override this method to support platform-specific error message formats.
    ///
    /// - Parameter json: The JSON response to extract the message from
    /// - Returns: An error message string, or `nil` if not found
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
    
    // MARK: - Helper Methods
    
    /// Parses JSON from an Alamofire response.
    ///
    /// Attempts to get JSON from the successful response value first,
    /// then falls back to parsing from raw data if available.
    ///
    /// - Parameter response: The Alamofire data response
    /// - Returns: The parsed JSON, or `nil` if parsing fails
    internal func parseJson(from response: DataResponse<JSON, AFError>) -> JSON? {
        if let jsonValue = response.value {
            return jsonValue
        } else if let data = response.data {
            return try? JSON(data: data)
        }
        return nil
    }
    
    /// Extracts an error message from the underlying Alamofire error.
    ///
    /// Attempts to get a localized description from the underlying error,
    /// then falls back to the AF error's description.
    ///
    /// - Parameter response: The Alamofire data response
    /// - Returns: An error message string, or `nil` if not available
    internal func extractUnderlyingErrorMessage(from response: DataResponse<JSON, AFError>) -> String? {
        if let error = response.error?.asAFError?.underlyingError?.localizedDescription {
            return error
        } else if let error = response.error?.localizedDescription {
            return error
        }
        return nil
    }
    
    // MARK: - Request Management
    
    /// Cancels all pending and active requests for this client.
    ///
    /// This method:
    /// 1. Sets `isReloadingCancelled` to `true`
    /// 2. Cancels all tasks in the session manager
    ///
    /// Use this when the user navigates away or explicitly cancels operations.
    ///
    /// **Example:**
    /// ```swift
    /// func viewDidDisappear() {
    ///     apiClient.cancelAllRequests()
    /// }
    /// ```
    public func cancelAllRequests() {
        isReloadingCancelled = true
        sessionManager.session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }
    
    /// Constructs a URL from a path string.
    ///
    /// This method:
    /// - Returns absolute URLs unchanged (if they have a scheme)
    /// - Resolves relative URLs against the `baseURLString`
    ///
    /// **Examples:**
    /// ```swift
    /// // Relative path
    /// let url1 = try url(for: "/users/me")
    /// // Returns: https://api.example.com/users/me
    ///
    /// // Absolute URL
    /// let url2 = try url(for: "https://other-api.com/data")
    /// // Returns: https://other-api.com/data
    /// ```
    ///
    /// - Parameter path: The path string (relative or absolute)
    /// - Returns: A constructed URL
    /// - Throws: `APWebAuthenticationError.unknown` if URL construction fails
    open func url(for path: String) throws(APWebAuthenticationError) -> URL {
        // Check if it's already an absolute URL
        if let absoluteURL = URL(string: path), absoluteURL.scheme != nil {
            return absoluteURL
        }
        
        // Construct URL relative to base
        guard let baseURL = URL(string: baseURLString)?.appendingPathComponent(path) else {
            throw APWebAuthenticationError.unknown
        }
        
        return baseURL
    }
}

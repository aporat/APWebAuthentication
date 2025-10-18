import Foundation
@preconcurrency import Alamofire
import CryptoKit
import SwiftyJSON
import AlamofireSwiftyJSON

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
    
    open func generateError(from response: DataResponse<JSON, AFError>) -> APWebAuthenticationError {
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
    
    
    @discardableResult
    public func request(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters = Parameters(),
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    )
    throws(APWebAuthenticationError) -> DataRequest
    {
        guard let url = URL(string: baseURLString)?.appendingPathComponent(path) else {
            throw APWebAuthenticationError.unknown
        }
        
        return sessionManager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
    }
    
    @discardableResult
    public func request(
        urlString: String,
        method: HTTPMethod = .get,
        parameters: Parameters = Parameters(),
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    )
    throws(APWebAuthenticationError) -> DataRequest
    {
        guard let url = URL(string: urlString) else {
            throw APWebAuthenticationError.unknown
        }
        
        return sessionManager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
    }
    
    @discardableResult
    public func request<Parameters: Encodable & Sendable>(
        urlString: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
        headers: HTTPHeaders? = nil
    )
    throws(APWebAuthenticationError) -> DataRequest
    {
        guard let url = URL(string: urlString) else {
            throw APWebAuthenticationError.unknown
        }
        
        return sessionManager.request(url, method: method, parameters: parameters, encoder: encoder, headers: headers)
    }
    
    @discardableResult
    public func request<Parameters: Encodable & Sendable>(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
        headers: HTTPHeaders? = nil
    )
    throws(APWebAuthenticationError) -> DataRequest
    {
        guard let url = URL(string: baseURLString)?.appendingPathComponent(path) else {
            throw APWebAuthenticationError.unknown
        }
        
        return sessionManager.request(url, method: method, parameters: parameters, encoder: encoder, headers: headers)
    }
    
    
    @discardableResult
    public func request(
        url: URL,
        method: HTTPMethod = .get,
        parameters: Parameters = Parameters(),
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    )
    throws(APWebAuthenticationError) -> DataRequest
    {
        sessionManager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
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
    
    open func decryptToken(_ payload: String?, tag: String?, iv: String?, password: String) -> String? {
        // Ensure all inputs are present and valid
        guard let payload = payload,
              let tag = tag,
              let iv = iv,
              let payloadData = Data(base64Encoded: payload),
              let tagData = Data(base64Encoded: tag),
              let ivData = Data(base64Encoded: iv) else {
            return nil
        }
        
        do {
            // Derive a 32-byte key from the password using SHA-256
            let passwordData = Data(password.utf8)
            let key = SHA256.hash(data: passwordData)
            let symmetricKey = SymmetricKey(data: key) // 256-bit key
            
            // Create the nonce (IV) for AES-GCM
            let nonce = try AES.GCM.Nonce(data: ivData)
            
            // Combine ciphertext and tag into a sealed box
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: payloadData, tag: tagData)
            
            // Decrypt the data
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            
            // Convert decrypted data to a UTF-8 string
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("Decryption failed: \(error.localizedDescription)")
            return nil
        }
    }
    
}

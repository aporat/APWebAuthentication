import Alamofire
import UIKit
import CryptoKit

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
    static let didRateLimitReached = Notification.Name(rawValue: "socialcore.client.ratelimit")
    static let didRateLimitSessionExpired = Notification.Name(rawValue: "socialcore.client.sessionexpired")
    static let didRateLimitCancelled = Notification.Name(rawValue: "socialcore.client.ratelimit.cancelled")
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

    @discardableResult
    public func request(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters = Parameters(),
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    )
        throws -> DataRequest
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
        throws -> DataRequest
    {
        guard let url = URL(string: urlString) else {
            throw APWebAuthenticationError.unknown
        }

        return sessionManager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
    }

    @discardableResult
    public func request<Parameters: Encodable>(
        urlString: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
        headers: HTTPHeaders? = nil
    )
        throws -> DataRequest
    {
        guard let url = URL(string: urlString) else {
            throw APWebAuthenticationError.unknown
        }

        return sessionManager.request(url, method: method, parameters: parameters, encoder: encoder, headers: headers)
    }

    @discardableResult
    public func request<Parameters: Encodable>(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
        headers: HTTPHeaders? = nil
    )
        throws -> DataRequest
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
        throws -> DataRequest
    {
        sessionManager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
    }

    public func cancelAllRequests() {
        isReloadingCancelled = true

        sessionManager.session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
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

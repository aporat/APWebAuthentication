import Alamofire
import CryptoSwift
import UIKit

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
    open var requestRetrier: AuthClientRequestRetrier
    open var requestInterceptor: RequestInterceptor

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
        requestRetrier = AuthClientRequestRetrier()
        requestInterceptor = Interceptor(adapters: [], retriers: [requestRetrier])
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
        guard let currentPayload = payload, let payloadData = Data(base64Encoded: currentPayload),
            let currentIv = iv, let ivData = Data(base64Encoded: currentIv),
            let currentTag = tag, let tagData = Data(base64Encoded: currentTag)
        else {
            return nil
        }

        do {
            let gcm = GCM(iv: ivData.allBytes, authenticationTag: tagData.allBytes)
            let aes = try AES(key: password.bytes, blockMode: gcm, padding: .noPadding)
            let hexToken = try aes.decrypt(payloadData.allBytes).toHexString()
            let token = String(data: Data(hex: hexToken), encoding: .utf8)
            return token
        } catch {
            return nil
        }
    }
}

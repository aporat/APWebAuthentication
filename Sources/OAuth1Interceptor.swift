import Foundation
import Alamofire
import CryptoSwift

// MARK: - OAuth1Error
public enum OAuth1Error: Error, Sendable {
    case missingURLInRequest
    case requestBodyNotUTF8Encodable
    case signatureGenerationFailed
}

// MARK: - OAuth1Interceptor
public final class OAuth1Interceptor: RequestInterceptor, @unchecked Sendable {
    
    private let consumerKey: String
    private let consumerSecret: String
    
    @MainActor
    public let auth: Auth1Authentication

    @MainActor
    public init(consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.auth = auth
    }

    // MARK: - RequestAdapter
    
    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        
        Task {
            guard let url = urlRequest.url else {
                completion(.failure(OAuth1Error.missingURLInRequest))
                return
            }

            let authToken = await auth.token
            let authSecret = await auth.secret
            let userAgent = await auth.userAgent
            
            var adaptedRequest = urlRequest
            var formParameters: [String: String] = [:]

            if adaptedRequest.method == .post, let httpBody = adaptedRequest.httpBody {
                guard let bodyString = String(data: httpBody, encoding: .utf8) else {
                    completion(.failure(OAuth1Error.requestBodyNotUTF8Encodable))
                    return
                }
                
                if let components = URLComponents(string: "?\(bodyString)") {
                    formParameters = components.queryItems?.reduce(into: [String: String]()) { result, item in
                        result[item.name] = item.value ?? ""
                    } ?? [:]
                }
            }
            
            do {
                let authHeader = try authorizationHeader(
                    for: url,
                    method: adaptedRequest.httpMethod ?? "GET",
                    formParameters: formParameters,
                    authToken: authToken,
                    authSecret: authSecret
                )
                adaptedRequest.headers.add(.authorization(authHeader))
            } catch {
                completion(.failure(error))
                return
            }

            if let userAgent = userAgent, !userAgent.isEmpty {
                adaptedRequest.headers.add(.userAgent(userAgent))
            }
            
            adaptedRequest.headers.add(.accept("application/json"))

            completion(.success(adaptedRequest))
        }
    }
}

// MARK: - Private Helpers
private extension OAuth1Interceptor {
    
    func authorizationHeader(
        for url: URL,
        method: String,
        formParameters: [String: String],
        authToken: String?,
        authSecret: String?
    ) throws -> String {
        
        var oauthParameters = buildOAuthParameters(token: authToken)

        let allParameters = oauthParameters
            .merging(formParameters, uniquingKeysWith: { _, new in new })
            .merging(url.parameters, uniquingKeysWith: { _, new in new })
        
        let parameterString = allParameters
            .map { ($0.key.urlEscaped, $0.value.urlEscaped) }
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")
        
        let signatureBase = [
            method.uppercased().urlEscaped,
            url.oAuthBaseURL?.urlEscaped,
            parameterString.urlEscaped
        ]
        .compactMap { $0 }
        .joined(separator: "&")

        let signingKey = "\(consumerSecret.urlEscaped)&\((authSecret ?? "").urlEscaped)"

        guard let signature = try? HMAC(key: signingKey, variant: .sha1)
                .authenticate(Array(signatureBase.utf8))
                .toBase64()
        else {
            throw OAuth1Error.signatureGenerationFailed
        }
        
        oauthParameters["oauth_signature"] = signature

        let headerParameters = oauthParameters
            .map { ($0.key.urlEscaped, $0.value.urlEscaped) }
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\"\($0.1)\"" }
            .joined(separator: ", ")

        return "OAuth \(headerParameters)"
    }

    func buildOAuthParameters(token: String?) -> [String: String] {
        var parameters: [String: String] = [
            "oauth_consumer_key": consumerKey,
            "oauth_signature_method": "HMAC-SHA1",
            "oauth_version": "1.0",
            "oauth_timestamp": String(Int(Date().timeIntervalSince1970)),
            "oauth_nonce": UUID().uuidString.replacingOccurrences(of: "-", with: ""),
        ]
        if let token = token, !token.isEmpty {
            parameters["oauth_token"] = token
        }
        return parameters
    }
}

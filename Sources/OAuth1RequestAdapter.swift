import Foundation
import Alamofire
import CryptoSwift

// MARK: - OAuth1Error
/// Defines errors specific to the OAuth1 request adaptation process.
public enum OAuth1Error: Error, Sendable { // Added Sendable
    case missingURLInRequest
    case requestBodyNotUTF8Encodable
    case signatureGenerationFailed
}

// MARK: - OAuth1RequestAdapter
/// An Alamofire `RequestAdapter` that applies an OAuth 1.0a signature to outgoing requests.
public final class OAuth1RequestAdapter: RequestAdapter, @unchecked Sendable { // Added @unchecked Sendable
    private let consumerKey: String
    private let consumerSecret: String
    
    // This is @MainActor-isolated
    @MainActor
    public let auth: Auth1Authentication

    @MainActor
    public init(consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.auth = auth
    }

    // REFACTOR: The `completion` handler is now correctly marked `@Sendable`
    // and uses `any Error` to match the `RequestAdapter` protocol.
    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        
        // REFACTOR: Wrap all logic in a `Task` to safely access
        // @MainActor-isolated properties from `auth`.
        Task {
            guard let url = urlRequest.url else {
                completion(.failure(OAuth1Error.missingURLInRequest))
                return
            }

            // Access `@MainActor` properties via `await`.
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
                // Use URLComponents for robust query string parsing.
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
private extension OAuth1RequestAdapter {
    /// Constructs the final "Authorization" header string for an OAuth 1.0a request.
    func authorizationHeader(
        for url: URL,
        method: String,
        formParameters: [String: String],
        authToken: String?,
        authSecret: String?
    ) throws -> String {
        
        // [RFC 5849 Section 3.1]
        var oauthParameters = buildOAuthParameters(token: authToken)

        // [RFC 5849 Section 3.4.1.3.1]
        // Combine all parameters (OAuth, form, and URL query) into a single collection.
        let allParameters = oauthParameters
            .merging(formParameters, uniquingKeysWith: { _, new in new })
            .merging(url.parameters, uniquingKeysWith: { _, new in new }) // Assumes `url.parameters` extension exists
        
        // Percent-encode, sort, and join all parameters to form the parameter string.
        let parameterString = allParameters
            .map { ($0.key.urlEscaped, $0.value.urlEscaped) }
            // FIX: Correctly sort by the key of the two tuples being compared.
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")
        
        // [RFC 5849 Section 3.4.1]
        // Construct the signature base string from the method, base URL, and parameter string.
        let signatureBase = [
            method.uppercased().urlEscaped,
            url.oAuthBaseURL?.urlEscaped, // Assumes `url.oAuthBaseURL` extension exists
            parameterString.urlEscaped
        ]
        .compactMap { $0 }
        .joined(separator: "&")

        // [RFC 5849 Section 3.4.2]
        // The signing key is composed of the consumer secret and the token secret.
        let signingKey = "\(consumerSecret.urlEscaped)&\((authSecret ?? "").urlEscaped)"

        // Generate the HMAC-SHA1 signature.
        guard let signature = try? HMAC(key: signingKey, variant: .sha1)
                .authenticate(Array(signatureBase.utf8))
                .toBase64()
        else {
            throw OAuth1Error.signatureGenerationFailed
        }
        
        oauthParameters["oauth_signature"] = signature

        // [RFC 5849 Section 3.5.1]
        // Build the final header value string.
        let headerParameters = oauthParameters
            .map { ($0.key.urlEscaped, $0.value.urlEscaped) }
            // FIX: Correctly sort by the key of the two tuples being compared.
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\"\($0.1)\"" }
            .joined(separator: ", ")

        return "OAuth \(headerParameters)"
    }

    /// Builds the dictionary of standard OAuth parameters.
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

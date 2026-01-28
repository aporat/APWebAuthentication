import Foundation
import Alamofire
import CryptoSwift

// MARK: - OAuth 1.0a Error

/// Errors that can occur during OAuth 1.0a request signing.
public enum OAuth1Error: Error, Sendable {
    
    /// The request is missing a URL.
    ///
    /// OAuth 1.0a requires a URL to generate signatures.
    case missingURLInRequest
    
    /// The request body could not be encoded as UTF-8.
    ///
    /// OAuth 1.0a needs to parse form-encoded body parameters for signature generation.
    case requestBodyNotUTF8Encodable
    
    /// Failed to generate the HMAC-SHA1 signature.
    ///
    /// This occurs when cryptographic operations fail.
    case signatureGenerationFailed
}

// MARK: - OAuth 1.0a Interceptor

/// Request interceptor that adds OAuth 1.0a authentication to HTTP requests.
///
/// `OAuth1Interceptor` implements the OAuth 1.0a specification (RFC 5849) by:
/// - Generating HMAC-SHA1 signatures for each request
/// - Adding OAuth parameters to the Authorization header
/// - Signing both query parameters and form body parameters
/// - Managing consumer and access token credentials
///
/// **OAuth 1.0a Flow:**
/// OAuth 1.0a uses HMAC-SHA1 to sign requests with:
/// - Consumer key + consumer secret (identifies the app)
/// - Access token + access token secret (identifies the user)
/// - Request parameters (URL query params + form body params)
/// - Timestamp and nonce (prevents replay attacks)
///
/// **Signature Base String:**
/// ```
/// {HTTP_METHOD}&{URL}&{SORTED_PARAMETERS}
/// ```
///
/// **Signing Key:**
/// ```
/// {consumer_secret}&{token_secret}
/// ```
///
/// **Example Usage:**
/// ```swift
/// let auth = Auth1Authentication()
/// auth.token = "user_token"
/// auth.secret = "user_secret"
///
/// let interceptor = OAuth1Interceptor(
///     consumerKey: "app_consumer_key",
///     consumerSecret: "app_consumer_secret",
///     auth: auth
/// )
///
/// let client = OAuth1Client(
///     baseURLString: "https://api.twitter.com/1.1/",
///     consumerKey: "app_consumer_key",
///     consumerSecret: "app_consumer_secret",
///     auth: auth
/// )
/// ```
///
/// **Platforms Using OAuth 1.0a:**
/// - Twitter/X
/// - Tumblr
/// - Some legacy APIs
///
/// - Note: The interceptor is marked `@unchecked Sendable` because it accesses
///         `@MainActor`-isolated authentication properties.
public final class OAuth1Interceptor: RequestInterceptor, Sendable {
    
    // MARK: - Properties
    
    /// The OAuth consumer key identifying the application.
    ///
    /// This is obtained when registering your app with the OAuth provider.
    private let consumerKey: String
    
    /// The OAuth consumer secret used for signing requests.
    ///
    /// This is the app's secret key, obtained during registration.
    /// It must be kept secure and never exposed in client code.
    private let consumerSecret: String
    
    /// The authentication manager containing user tokens and configuration.
    ///
    /// Provides access to the user's access token and secret.
    @MainActor
    public let auth: Auth1Authentication

    // MARK: - Initialization
    
    /// Creates a new OAuth 1.0a request interceptor.
    ///
    /// - Parameters:
    ///   - consumerKey: The OAuth consumer key (app identifier)
    ///   - consumerSecret: The OAuth consumer secret (app secret)
    ///   - auth: The authentication manager with user tokens
    @MainActor
    public init(consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.auth = auth
    }

    // MARK: - RequestAdapter
    
    /// Adapts requests by adding OAuth 1.0a authentication.
    ///
    /// This method:
    /// 1. Extracts form parameters from POST body
    /// 2. Generates OAuth signature base string
    /// 3. Signs the request with HMAC-SHA1
    /// 4. Adds Authorization header with OAuth parameters
    /// 5. Adds user agent and Accept headers
    ///
    /// **Authorization Header Format:**
    /// ```
    /// OAuth oauth_consumer_key="...", oauth_nonce="...",
    ///       oauth_signature="...", oauth_signature_method="HMAC-SHA1",
    ///       oauth_timestamp="...", oauth_token="...", oauth_version="1.0"
    /// ```
    ///
    /// - Parameters:
    ///   - urlRequest: The request to adapt
    ///   - session: The Alamofire session
    ///   - completion: Completion handler with adapted request or error
    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
    ) {
        Task {
            // Validate URL presence
            guard let url = urlRequest.url else {
                completion(.failure(OAuth1Error.missingURLInRequest))
                return
            }

            // Get user credentials from auth
            let authToken = await auth.token
            let authSecret = await auth.secret
            let userAgent = await auth.userAgent
            
            var adaptedRequest = urlRequest
            var formParameters: [String: String] = [:]

            // Extract form parameters from POST body
            if adaptedRequest.method == .post, let httpBody = adaptedRequest.httpBody {
                guard let bodyString = String(data: httpBody, encoding: .utf8) else {
                    completion(.failure(OAuth1Error.requestBodyNotUTF8Encodable))
                    return
                }
                
                // Parse form-encoded parameters
                if let components = URLComponents(string: "?\(bodyString)") {
                    formParameters = components.queryItems?.reduce(into: [String: String]()) { result, item in
                        result[item.name] = item.value ?? ""
                    } ?? [:]
                }
            }
            
            // Generate OAuth signature and authorization header
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

            // Add user agent if available
            if let userAgent = userAgent, !userAgent.isEmpty {
                adaptedRequest.headers.add(.userAgent(userAgent))
            }
            
            // Add Accept header
            adaptedRequest.headers.add(.accept("application/json"))

            completion(.success(adaptedRequest))
        }
    }
}

// MARK: - OAuth 1.0a Signature Generation

private extension OAuth1Interceptor {
    
    /// Generates the OAuth 1.0a Authorization header value.
    ///
    /// This method implements the OAuth 1.0a signature generation algorithm:
    /// 1. Builds OAuth parameters (consumer key, nonce, timestamp, etc.)
    /// 2. Combines all parameters (OAuth + query + form)
    /// 3. Creates signature base string
    /// 4. Generates HMAC-SHA1 signature
    /// 5. Formats Authorization header
    ///
    /// **Signature Algorithm:**
    /// ```
    /// signature_base = HTTP_METHOD & URL & sorted_parameters
    /// signing_key = consumer_secret & token_secret
    /// signature = HMAC-SHA1(signing_key, signature_base)
    /// ```
    ///
    /// - Parameters:
    ///   - url: The request URL
    ///   - method: The HTTP method (GET, POST, etc.)
    ///   - formParameters: Form-encoded body parameters
    ///   - authToken: The user's access token
    ///   - authSecret: The user's access token secret
    ///
    /// - Returns: The OAuth Authorization header value
    /// - Throws: `OAuth1Error` if signature generation fails
    func authorizationHeader(
        for url: URL,
        method: String,
        formParameters: [String: String],
        authToken: String?,
        authSecret: String?
    ) throws -> String {
        
        // Build OAuth parameters (consumer key, nonce, timestamp, etc.)
        var oauthParameters = buildOAuthParameters(token: authToken)

        // Combine all parameters for signing
        let allParameters = oauthParameters
            .merging(formParameters, uniquingKeysWith: { _, new in new })
            .merging(url.parameters, uniquingKeysWith: { _, new in new })
        
        // Create sorted parameter string
        let parameterString = allParameters
            .map { ($0.key.urlEscaped, $0.value.urlEscaped) }
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")
        
        // Create signature base string
        let signatureBase = [
            method.uppercased().urlEscaped,
            url.oAuthBaseURL?.urlEscaped,
            parameterString.urlEscaped
        ]
        .compactMap { $0 }
        .joined(separator: "&")

        // Create signing key
        let signingKey = "\(consumerSecret.urlEscaped)&\((authSecret ?? "").urlEscaped)"

        // Generate HMAC-SHA1 signature
        guard let signature = try? HMAC(key: signingKey, variant: .sha1)
                .authenticate(Array(signatureBase.utf8))
                .toBase64()
        else {
            throw OAuth1Error.signatureGenerationFailed
        }
        
        oauthParameters["oauth_signature"] = signature

        // Format OAuth header
        let headerParameters = oauthParameters
            .map { ($0.key.urlEscaped, $0.value.urlEscaped) }
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\"\($0.1)\"" }
            .joined(separator: ", ")

        return "OAuth \(headerParameters)"
    }

    /// Builds the OAuth parameters for the request.
    ///
    /// Creates the standard OAuth 1.0a parameters:
    /// - `oauth_consumer_key`: App identifier
    /// - `oauth_signature_method`: Always "HMAC-SHA1"
    /// - `oauth_version`: Always "1.0"
    /// - `oauth_timestamp`: Current Unix timestamp
    /// - `oauth_nonce`: Random unique string (prevents replay)
    /// - `oauth_token`: User's access token (if available)
    ///
    /// **Nonce Generation:**
    /// Uses a UUID without hyphens as a unique identifier.
    ///
    /// - Parameter token: The user's OAuth access token (optional)
    /// - Returns: A dictionary of OAuth parameters
    func buildOAuthParameters(token: String?) -> [String: String] {
        var parameters: [String: String] = [
            "oauth_consumer_key": consumerKey,
            "oauth_signature_method": "HMAC-SHA1",
            "oauth_version": "1.0",
            "oauth_timestamp": String(Int(Date().timeIntervalSince1970)),
            "oauth_nonce": UUID().uuidString.replacingOccurrences(of: "-", with: ""),
        ]
        
        // Add token if available
        if let token = token, !token.isEmpty {
            parameters["oauth_token"] = token
        }
        
        return parameters
    }
}

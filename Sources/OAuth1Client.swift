import Alamofire
import Foundation
@preconcurrency import SwiftyJSON

/// HTTP client for OAuth 1.0a authenticated APIs.
///
/// `OAuth1Client` extends `AuthClient` to provide OAuth 1.0a authentication support.
/// It handles:
/// - OAuth 1.0a signature generation
/// - Request signing with consumer key/secret
/// - User agent and browser mode configuration
///
/// **OAuth 1.0a Flow:**
/// OAuth 1.0a uses HMAC-SHA1 signatures to authenticate requests. Each request
/// is signed using:
/// - Consumer key (identifies the app)
/// - Consumer secret (app's secret key)
/// - Access token (user's token)
/// - Access token secret (user's secret)
///
/// **Example:**
/// ```swift
/// let auth = Auth1Authentication(
///     consumerKey: "your_key",
///     consumerSecret: "your_secret"
/// )
///
/// let client = OAuth1Client(
///     baseURLString: "https://api.twitter.com/1.1/",
///     consumerKey: "your_key",
///     consumerSecret: "your_secret",
///     auth: auth
/// )
///
/// let json = try await client.request("/account/verify_credentials.json")
/// ```
///
/// - Note: OAuth 1.0a is used by platforms like Twitter (X) and Tumblr.
@MainActor
open class OAuth1Client: AuthClient {

    // MARK: - Properties

    /// The OAuth 1.0a request interceptor handling signature generation.
    ///
    /// This interceptor adds the OAuth authorization header to each request
    /// with the required signatures and nonces.
    private var interceptor: OAuth1Interceptor

    // MARK: - Initialization

    /// Creates a new OAuth 1.0a client with the specified configuration.
    ///
    /// - Parameters:
    ///   - accountType: The account type/platform this client targets
    ///   - baseURLString: The base URL for all API requests
    ///   - consumerKey: The OAuth consumer key (identifies your app)
    ///   - consumerSecret: The OAuth consumer secret (your app's secret key)
    ///   - auth: The authentication object containing user tokens
    public init(
        accountType: AccountType,
        baseURLString: String,
        consumerKey: String,
        consumerSecret: String,
        auth: Auth1Authentication
    ) {
        let interceptor = OAuth1Interceptor(
            consumerKey: consumerKey,
            consumerSecret: consumerSecret,
            auth: auth
        )

        self.interceptor = interceptor
        super.init(accountType: accountType, baseURLString: baseURLString, requestInterceptor: interceptor)
    }
}

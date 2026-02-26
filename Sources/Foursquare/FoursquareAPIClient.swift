import Alamofire
import Foundation
@preconcurrency import SwiftyJSON

/// HTTP client for the Foursquare API with OAuth 2.0 authentication.
///
/// `FoursquareAPIClient` provides authenticated access to the Foursquare API v2.
/// It handles:
/// - OAuth 2.0 bearer token authentication
/// - Automatic API versioning (via interceptor)
/// - Foursquare-specific error message extraction
///
/// **Example Usage:**
/// ```swift
/// let auth = Auth2Authentication()
/// auth.accessToken = "user_oauth_token"
/// 
/// let client = FoursquareAPIClient(auth: auth)
/// let venues = try await client.request("/venues/search", params: ["near": "San Francisco"])
/// ```
///
/// - Note: Foursquare API requires a version parameter (v) on all requests, which is automatically added by the interceptor.
@MainActor
public final class FoursquareAPIClient: OAuth2Client {

    // MARK: - Initialization

    /// Creates a new Foursquare API client with OAuth 2.0 authentication.
    ///
    /// This is the primary initializer for most use cases. It automatically
    /// configures the client with Foursquare's base URL and creates an
    /// appropriate request interceptor.
    ///
    /// - Parameter auth: The OAuth 2.0 authentication credentials
    public convenience init(auth: Auth2Authentication) {
        let interceptor = FoursquareInterceptor(auth: auth)
        self.init(
            baseURLString: "https://api.foursquare.com/v2/",
            requestInterceptor: interceptor
        )
    }

    /// Creates a new Foursquare API client with a custom base URL and interceptor.
    ///
    /// Use this initializer for advanced configurations such as testing with
    /// a mock server or using a custom interceptor implementation.
    ///
    /// - Parameters:
    ///   - baseURLString: The base URL for all API requests
    ///   - requestInterceptor: The request interceptor for authentication
    public init(baseURLString: String, requestInterceptor: FoursquareInterceptor) {
        super.init(
            accountType: AccountStore.foursquare,
            baseURLString: baseURLString,
            requestInterceptor: requestInterceptor
        )
    }

    // MARK: - Error Handling

    /// Extracts error messages from Foursquare API error responses.
    ///
    /// Foursquare returns errors in the format:
    /// ```json
    /// {
    ///   "meta": {
    ///     "code": 400,
    ///     "errorType": "param_error",
    ///     "errorDetail": "Missing required parameter: ll"
    ///   }
    /// }
    /// ```
    ///
    /// - Parameter json: The error response JSON
    /// - Returns: The error message if found, otherwise falls back to parent implementation
    override public func extractErrorMessage(from json: JSON?) -> String? {
        if let message = json?["meta"]["errorDetail"].string {
            return message
        }

        return super.extractErrorMessage(from: json)
    }
}

import Alamofire
import Foundation

/// Request interceptor for the Foursquare API with OAuth 2.0 authentication.
///
/// `FoursquareInterceptor` extends `OAuth2Interceptor` to provide Foursquare-specific
/// request handling:
/// - OAuth 2.0 token authentication (as `oauth_token` parameter)
/// - Automatic API versioning (via `v` parameter)
///
/// **Foursquare API Requirements:**
///
/// Foursquare requires two critical parameters on every request:
/// 1. **`oauth_token`** - The OAuth 2.0 access token
/// 2. **`v`** - API version date in `YYYYMMDD` format
///
/// **Example Request:**
/// ```
/// GET https://api.foursquare.com/v2/venues/search?
///     oauth_token={access_token}&
///     v=20240109&
///     near=San%20Francisco
/// ```
///
/// **Version Parameter:**
/// The `v` parameter tells Foursquare which version of the API to use.
/// It's a date string that locks your app to specific API behaviors.
/// This prevents breaking changes from affecting your app.
///
/// Current version: `20240109` (January 9, 2024)
///
/// **Example Usage:**
/// ```swift
/// let auth = Auth2Authentication()
/// auth.accessToken = "foursquare_oauth_token"
///
/// let interceptor = FoursquareInterceptor(auth: auth)
/// // Automatically adds oauth_token and v parameters to all requests
/// ```
///
/// - Note: Unlike most OAuth 2.0 APIs, Foursquare uses a query parameter (`oauth_token`)
///         instead of the Authorization header.
@MainActor
public final class FoursquareInterceptor: OAuth2Interceptor, @unchecked Sendable {

    // MARK: - Initialization

    /// Creates a new Foursquare API request interceptor.
    ///
    /// Configures the interceptor with Foursquare-specific settings:
    /// - Token location: Query parameter (not Authorization header)
    /// - Token parameter name: `oauth_token` (not standard `access_token`)
    ///
    /// - Parameter auth: The OAuth 2.0 authentication credentials
    public init(auth: Auth2Authentication) {
        super.init(
            auth: auth,
            tokenLocation: .params,
            tokenParamName: "oauth_token",
            tokenHeaderParamName: "Bearer"
        )
    }

    // MARK: - RequestAdapter

    /// Adapts requests by adding Foursquare-specific parameters.
    ///
    /// This method:
    /// 1. Adds the required API version parameter (`v=20240109`)
    /// 2. Calls the parent implementation to add OAuth token
    /// 3. Adds user agent and other standard headers
    ///
    /// **Parameters Added:**
    /// - `v`: API version date (required by Foursquare)
    /// - `oauth_token`: OAuth 2.0 access token (added by parent)
    ///
    /// **Example Result:**
    /// ```
    /// GET /v2/venues/search?oauth_token={token}&v=20240109&near=SF
    /// ```
    ///
    /// - Parameters:
    ///   - urlRequest: The request to adapt
    ///   - session: The Alamofire session
    ///   - completion: Completion handler with adapted request or error
    override public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
    ) {
        var urlRequest = urlRequest

        // Add required Foursquare API version parameter
        // Version format: YYYYMMDD (locks API behavior to specific date)
        let params: Parameters = ["v": "20240109"]

        do {
            urlRequest = try URLEncoding.default.encode(urlRequest, with: params)
            // Let parent add OAuth token and other headers
            super.adapt(urlRequest, for: session, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
}

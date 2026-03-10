import Alamofire
import Foundation
@preconcurrency import SwiftyJSON

// MARK: - BlueskyAPIClient

/// HTTP client for the Bluesky / AT Protocol XRPC API with DPoP-bound OAuth 2.0.
///
/// `BlueskyAPIClient` provides authenticated access to the AT Protocol API.
/// It handles:
/// - DPoP-bound OAuth 2.0 token authentication (RFC 9449)
/// - AT Protocol XRPC endpoint conventions
/// - Bluesky-specific error message extraction
///
/// **Base URL:** `https://bsky.social/xrpc/`
///
/// For users hosted on a custom PDS, supply the PDS host via the
/// `init(pdsHost:auth:)` convenience initializer.
///
/// **Example Usage:**
/// ```swift
/// let auth = BlueskyAuthentication()
/// auth.accessToken = "<access_token>"
/// auth.did = "did:plc:abc123"
///
/// // Default (Bluesky-hosted PDS / AppView)
/// let client = BlueskyAPIClient(auth: auth)
///
/// // Fetch actor profile
/// let profile = try await client.request(
///     "app.bsky.actor.getProfile",
///     parameters: ["actor": auth.did ?? ""]
/// )
/// ```
@MainActor
public final class BlueskyAPIClient: OAuth2Client {

    // MARK: - Initialization

    /// Creates a Bluesky API client targeting `bsky.social`.
    ///
    /// - Parameter auth: The Bluesky authentication credentials.
    public convenience init(auth: BlueskyAuthentication) {
        let interceptor = BlueskyInterceptor(auth: auth)
        self.init(
            baseURLString: "https://bsky.social/xrpc/",
            requestInterceptor: interceptor
        )
    }

    /// Creates a Bluesky API client targeting a custom PDS host.
    ///
    /// Use this when the authenticated account lives on a self-hosted PDS.
    ///
    /// - Parameters:
    ///   - pdsHost: The PDS hostname, e.g. `"pds.example.com"`.
    ///   - auth: The Bluesky authentication credentials.
    public convenience init(pdsHost: String, auth: BlueskyAuthentication) {
        let interceptor = BlueskyInterceptor(auth: auth)
        self.init(
            baseURLString: "https://\(pdsHost)/xrpc/",
            requestInterceptor: interceptor
        )
    }

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - baseURLString: The XRPC base URL (must end with `/xrpc/`).
    ///   - requestInterceptor: The DPoP-aware interceptor.
    public init(baseURLString: String, requestInterceptor: BlueskyInterceptor) {
        super.init(
            accountType: AccountStore.bluesky,
            baseURLString: baseURLString,
            requestInterceptor: requestInterceptor
        )
    }

    // MARK: - Error Extraction

    /// Extracts a human-readable error message from an AT Protocol XRPC error response.
    ///
    /// AT Protocol error responses use the format:
    /// ```json
    /// { "error": "InvalidToken", "message": "Token has been revoked" }
    /// ```
    override public func extractErrorMessage(from json: JSON?) -> String? {
        if let message = json?["message"].string, !message.isEmpty {
            return message
        }
        if let error = json?["error"].string, !error.isEmpty {
            return error
        }
        return nil
    }
}

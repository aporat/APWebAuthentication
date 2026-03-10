import Foundation
@preconcurrency import SwiftyJSON

// MARK: - BlueskyUser

/// Represents a Bluesky / AT Protocol actor profile.
///
/// Maps the `app.bsky.actor.getProfile` response to the common `User` protocol.
///
/// **Example API Response:**
/// ```json
/// {
///   "did": "did:plc:abc123",
///   "handle": "user.bsky.social",
///   "displayName": "Alice",
///   "avatar": "https://cdn.bsky.app/img/avatar/...",
///   "followersCount": 100,
///   "followsCount": 50,
///   "postsCount": 200
/// }
/// ```
///
/// **Example Usage:**
/// ```swift
/// let client = BlueskyAPIClient(auth: auth)
/// let json = try await client.request("app.bsky.actor.getProfile", parameters: ["actor": "user.bsky.social"])
/// let user = BlueskyUser(info: json)
/// ```
public final class BlueskyUser: GenericUser, @unchecked Sendable {

    // MARK: - AT Protocol Properties

    /// The account's Decentralized Identifier, e.g. `did:plc:abc123`.
    public let did: String

    /// The AT Protocol handle, e.g. `user.bsky.social`.
    public let handle: String?

    /// Number of posts the user has made.
    public var postsCount: Int32?

    // MARK: - Initialization

    /// Creates a `BlueskyUser` from an `app.bsky.actor.getProfile` JSON response.
    ///
    /// - Parameter info: JSON from the AT Protocol actor profile endpoint.
    /// - Returns: `BlueskyUser` instance, or `nil` if the required `did` field is absent.
    public required init?(info: JSON) {
        let did = info["did"].stringValue
        guard !did.isEmpty else { return nil }

        self.did = did
        self.handle = info["handle"].string

        super.init(
            userId: did,
            username: info["handle"].string,
            fullname: info["displayName"].string,
            avatarPicture: info["avatar"].url
        )

        followersCount = info["followersCount"].int32
        followingCount = info["followsCount"].int32
        postsCount = info["postsCount"].int32
    }
}

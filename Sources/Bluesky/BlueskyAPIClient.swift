import Foundation

// MARK: - BlueskyAPIClient

/// XRPC client for a Bluesky session. See ``ATProtoClient`` for the request
/// surface; this only fixes the account type.
@MainActor
public final class BlueskyAPIClient: ATProtoClient {

    /// The AppView the PDS proxies `app.bsky.*` reads to; `rpc:` and
    /// `include:` permissions must name it as their audience.
    nonisolated public static let appViewAudience = "did:web:api.bsky.app#bsky_appview"

    /// Least-privilege scope for a follower analytics client, per
    /// https://atproto.com/specs/permission:
    /// - `atproto`: the session itself.
    /// - `include:app.bsky.authViewAll`: Bluesky's read-only permission set,
    ///   which covers `getProfile`, `getFollowers`, `getFollows` and
    ///   `getRelationships` through the PDS proxy.
    /// - `repo:app.bsky.graph.follow`: create and delete follow records.
    ///
    /// The client metadata document must declare at least these; a login
    /// may only request a subset of what the metadata lists.
    nonisolated public static let defaultScope = [
        "atproto",
        "include:app.bsky.authViewAll?aud=" + appViewAudience.replacingOccurrences(of: "#", with: "%23"),
        "repo:app.bsky.graph.follow?action=create&action=delete"
    ].joined(separator: " ")

    public init(auth: ATProtoAuthentication, oauthClient: ATProtoOAuthClient? = nil) {
        super.init(accountType: AccountStore.bluesky, auth: auth, oauthClient: oauthClient)
    }
}

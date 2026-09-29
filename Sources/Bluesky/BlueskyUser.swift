import Foundation
@preconcurrency import SwiftyJSON

// MARK: - BlueskyUser

/// A user parsed from any of the `app.bsky.actor.defs#profileView*` shapes.
///
/// The DID is the identifier; handles can change. `followsCount` maps to
/// `followingCount` and `postsCount` to `mediaCount`.
public final class BlueskyUser: GenericUser, @unchecked Sendable {

    /// The AT-URI of the signed-in user's follow record for this account
    /// (`viewer.following`), which is what an unfollow deletes.
    public let followURI: String?

    /// True when this account follows the signed-in user.
    public let isFollowingMe: Bool

    /// True when the signed-in user has blocked this account.
    public let isBlocked: Bool

    /// True when this account has blocked the signed-in user.
    public let isBlockingMe: Bool

    // MARK: - Initialization

    public required init?(info: JSON) {
        let did = info["did"].stringValue
        guard did.hasPrefix("did:") else {
            return nil
        }

        let viewer = info["viewer"]
        followURI = viewer["following"].string
        isFollowingMe = viewer["followedBy"].string != nil
        isBlocked = viewer["blocking"].string != nil
        isBlockingMe = viewer["blockedBy"].boolValue

        let displayName = info["displayName"].string?.trimmingCharacters(in: .whitespacesAndNewlines)

        super.init(
            userId: did,
            username: info["handle"].string,
            fullname: (displayName?.isEmpty ?? true) ? nil : displayName,
            avatarPicture: info["avatar"].url
        )

        followersCount = info["followersCount"].int32
        followingCount = info["followsCount"].int32
        mediaCount = info["postsCount"].int32
    }

    // MARK: - Follow Records

    /// The record key of a follow AT-URI: `at://did/app.bsky.graph.follow/<rkey>`.
    public static func recordKey(fromATURI uri: String) -> String? {
        guard uri.hasPrefix("at://") else { return nil }
        let parts = uri.dropFirst("at://".count).split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3, !parts[2].isEmpty else { return nil }
        return String(parts[2])
    }
}

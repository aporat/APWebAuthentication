import Foundation
@preconcurrency import SwiftyJSON

// MARK: - MastodonUser

/// An account as the Mastodon API returns it (`Account` entity).
///
/// `userId` is the account's id *on the signed-in user's server*. Remote
/// accounts get a local id on every server that knows them, so ids only mean
/// something within one session; the full handle is what travels.
public final class MastodonUser: GenericUser, @unchecked Sendable {

    // MARK: - Properties

    /// The account's web profile, as the server reports it.
    public let profileURL: URL?

    /// Whether the server flags the account as automated.
    public let isBot: Bool

    // MARK: - Initialization

    /// Creates a user from an `Account` JSON object.
    ///
    /// - Parameters:
    ///   - info: The account JSON
    ///   - host: The signed-in user's server. Accounts local to it come back
    ///     with a bare `acct` (`alice`); the host is appended so every
    ///     username is a full handle (`alice@mastodon.social`).
    public init?(info: JSON, host: String?) {
        let id = info["id"].stringValue
        guard !id.isEmpty else { return nil }

        let acct = info["acct"].string.flatMap { $0.isEmpty ? nil : $0 }
            ?? info["username"].string.flatMap { $0.isEmpty ? nil : $0 }
        let username = Self.fullHandle(acct: acct, host: host)

        // Display names are optional and often blank; fall back to the
        // handle so the row never shows empty.
        let displayName = info["display_name"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullname = (displayName?.isEmpty == false) ? displayName : nil

        profileURL = info["url"].url
        isBot = info["bot"].boolValue

        super.init(
            userId: id,
            username: username,
            fullname: fullname,
            avatarPicture: info["avatar"].url ?? info["avatar_static"].url,
            privateProfile: info["locked"].boolValue
        )

        followersCount = Self.count(info["followers_count"])
        followingCount = Self.count(info["following_count"])
        mediaCount = Self.count(info["statuses_count"])
    }

    public convenience init?(info: JSON) {
        self.init(info: info, host: nil)
    }

    // MARK: - Helpers

    /// `alice` on `mastodon.social` → `alice@mastodon.social`; an `acct`
    /// that already carries a domain is returned as is.
    nonisolated static func fullHandle(acct: String?, host: String?) -> String? {
        guard let acct, !acct.isEmpty else { return nil }
        if acct.contains("@") { return acct }
        guard let host, !host.isEmpty else { return acct }
        return "\(acct)@\(host)"
    }

    /// Servers report `-1` for counts the account hides; treat that as unknown.
    nonisolated private static func count(_ value: JSON) -> Int32? {
        guard let count = value.int32, count >= 0 else { return nil }
        return count
    }
}

// MARK: - MastodonRelationship

/// The signed-in user's relationship with one account (`Relationship` entity).
public struct MastodonRelationship: Sendable, Equatable {

    public let userId: String
    public let following: Bool
    public let followedBy: Bool
    public let requested: Bool
    public let blocking: Bool
    public let blockedBy: Bool

    public init?(info: JSON) {
        let id = info["id"].stringValue
        guard !id.isEmpty else { return nil }

        userId = id
        following = info["following"].boolValue
        followedBy = info["followed_by"].boolValue
        requested = info["requested"].boolValue
        blocking = info["blocking"].boolValue
        blockedBy = info["blocked_by"].boolValue
    }
}

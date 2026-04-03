import Foundation
@preconcurrency import SwiftyJSON

// MARK: - XUser

/// Represents an X (Twitter) user profile.
///
/// Maps the X API v2 `users/me` response to the common `User` protocol.
///
/// **Example API Response:**
/// ```json
/// {
///   "data": {
///     "id": "2035675281458167808",
///     "name": "TruWrite",
///     "profile_image_url": "https://pbs.twimg.com/profile_images/.../photo_normal.jpg",
///     "public_metrics": {
///       "followers_count": 0,
///       "following_count": 0,
///       "like_count": 0,
///       "listed_count": 0,
///       "media_count": 0,
///       "tweet_count": 0
///     },
///     "username": "truwrite"
///   }
/// }
/// ```
public final class XUser: GenericUser, @unchecked Sendable {

    /// Number of tweets/posts the user has made.
    public var tweetCount: Int32?

    // MARK: - Initialization

    public required init?(info: JSON) {
        // Support both unwrapped and "data"-wrapped responses
        let user = info["data"].exists() ? info["data"] : info

        guard let id = user["id"].string else {
            return nil
        }

        let username = user["username"].string
        let fullname = user["name"].string
        let isVerified = user["verified"].bool ?? false
        let privateProfile = user["protected"].bool ?? false

        // Process avatar URL (remove '_normal' suffix for higher quality)
        let constructedAvatarPicture: URL?
        if let pictureString = user["profile_image_url"].string {
            let biggerPictureString = pictureString.replacingOccurrences(of: "_normal", with: "")
            constructedAvatarPicture = URL(string: biggerPictureString)
        } else {
            constructedAvatarPicture = nil
        }

        let metrics = user["public_metrics"]
        self.tweetCount = metrics["tweet_count"].int32

        super.init(
            userId: id,
            username: username,
            fullname: fullname,
            avatarPicture: constructedAvatarPicture,
            privateProfile: privateProfile,
            verified: isVerified
        )

        followersCount = metrics["followers_count"].int32
        followingCount = metrics["following_count"].int32
        mediaCount = metrics["media_count"].int32
        likesCount = metrics["like_count"].int32
    }
}

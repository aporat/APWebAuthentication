import Foundation
@preconcurrency import SwiftyJSON

// MARK: - RedditUser

/// Represents a Reddit user profile.
///
/// Maps Reddit API user data to the common User protocol.
/// Note: Reddit uses `name` for both username and full name since it has no separate display name.
public final class RedditUser: GenericUser, @unchecked Sendable {

    // MARK: - Initialization

    /// Creates a RedditUser from API response JSON.
    ///
    /// - Parameter info: JSON response from Reddit API
    /// - Returns: RedditUser instance, or nil if required fields are missing
    public required init?(info: JSON) {
        // Extract user ID
        guard let id = info["id"].string else {
            return nil
        }

        // Extract profile information
        let name = info["name"].string
        let avatarPicture = info["icon_img"].url
        let isVerified = info["verified"].bool ?? false

        super.init(
            userId: id,
            username: name,
            fullname: name,
            avatarPicture: avatarPicture,
            privateProfile: false,
            verified: isVerified
        )
    }
}

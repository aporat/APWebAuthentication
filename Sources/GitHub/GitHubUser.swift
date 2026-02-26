import Foundation
@preconcurrency import SwiftyJSON

// MARK: - GitHubUser

/// Represents a GitHub user profile.
///
/// Maps GitHub API user data to the common User protocol, including
/// social statistics like followers and following counts.
public final class GitHubUser: GenericUser, @unchecked Sendable {

    // MARK: - Initialization

    /// Creates a GitHubUser from API response JSON.
    ///
    /// - Parameter info: JSON response from GitHub API
    /// - Returns: GitHubUser instance, or nil if required fields are missing
    public required init?(info: JSON) {
        // Extract user ID (required)
        let id = info["id"].stringValue
        guard !id.isEmpty else {
            return nil
        }

        super.init(
            userId: id,
            username: info["login"].string,
            fullname: info["name"].string,
            avatarPicture: info["avatar_url"].url
        )

        // Set social statistics
        followersCount = info["followers"].int32
        followingCount = info["following"].int32
    }
}


import Foundation
@preconcurrency import SwiftyJSON

// MARK: - PinterestWebUser

public final class PinterestWebUser: GenericUser, @unchecked Sendable {

    // MARK: - Initialization

    public required init?(info: JSON) {
        // Extract user ID
        guard let id = info["id"].idString else {
            return nil
        }

        // Extract profile information
        let username = info["username"].string
        let fullname = info["full_name"].string
        let avatarPicture = info["image_medium_url"].url

        super.init(
            userId: id,
            username: username,
            fullname: fullname,
            avatarPicture: avatarPicture
        )

        // Set social metrics
        followersCount = info["follower_count"].int32
        followingCount = info["following_count"].int32
    }
}

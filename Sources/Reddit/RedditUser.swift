import Foundation
@preconcurrency import SwiftyJSON

// MARK: - RedditUser

public final class RedditUser: GenericUser, @unchecked Sendable {

    // MARK: - Initialization

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

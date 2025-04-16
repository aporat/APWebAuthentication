import Foundation
import SwiftyJSON

public final class TwitchUser: BaseUser {
    public required init?(info: JSON) {
        if let id = info["id"].idString {
            super.init(userId: id)
        } else if let id = info["_id"].idString {
            super.init(userId: id)
        } else {
            return nil
        }

        if let currentUsername = info["name"].string {
            username = currentUsername
        } else if let currentUsername = info["login"].string {
            username = currentUsername
        }

        fullname = info["display_name"].string

        if let currentProfilePicture = info["logo"].url {
            avatarPicture = currentProfilePicture
        } else if let currentProfilePicture = info["profile_image_url"].url {
            avatarPicture = currentProfilePicture
        }
    }
}

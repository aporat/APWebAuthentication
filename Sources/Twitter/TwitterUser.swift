import Foundation
import SwiftyJSON

public final class TwitterUser: GenericUser, @unchecked Sendable {
    public required init?(info: JSON) {
        if let id = info["id_str"].idString {
            super.init(userId: id)
        } else if let id = info["id"].idString {
            super.init(userId: String(id))
        } else {
            return nil
        }

        username = info["username"].string
        fullname = info["name"].string

        if let currentProfilePicture = info["profile_image_url"].string {
            avatarPicture = URL(string: currentProfilePicture.replacingOccurrences(of: "_normal", with: "_bigger"))
        }
    }
}

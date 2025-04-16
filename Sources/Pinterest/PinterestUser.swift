import Foundation
import SwiftyJSON

public final class PinterestUser: BaseUser {
    public required init?(info: JSON) {
        if let id = info["id"].idString {
            super.init(userId: id)
        } else if let id = info["username"].idString {
            super.init(userId: id)
        } else {
            return nil
        }

        username = info["username"].string

        if let currentFirstName = info["first_name"].string, let currentLastName = info["last_name"].string {
            fullname = currentFirstName + " " + currentLastName
        }

        avatarPicture = info["profile_image"].url
    }
}

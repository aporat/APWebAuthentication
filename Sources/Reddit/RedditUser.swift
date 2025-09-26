import Foundation
import SwiftyJSON

public final class RedditUser: GenericUser, @unchecked Sendable {
    public required init?(info: JSON) {
        if let id = info["id"].idString {
            super.init(userId: id)
        } else {
            return nil
        }

        username = info["name"].string
        fullname = info["name"].string
        avatarPicture = info["icon_img"].url
    }
}

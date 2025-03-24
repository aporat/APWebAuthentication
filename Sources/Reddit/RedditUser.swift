import SwiftyJSON

public final class RedditUser: BaseUser {
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

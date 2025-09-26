import Foundation
import SwiftyJSON

public final class PinterestWebUser: GenericUser, @unchecked Sendable {
    public required init?(info: JSON) {
        if let id = info["id"].idString {
            super.init(userId: id)
        } else {
            return nil
        }

        username = info["username"].string
        fullname = info["full_name"].string
        avatarPicture = info["image_medium_url"].url
    }
}

import Foundation
import SwiftyJSON

public final class FiveHundredspxWebUser: BaseUser {
    public required init?(info: JSON) {
        if let id = info["id"].idString {
            super.init(userId: id)
        } else {
            return nil
        }

        username = info["username"].string
        fullname = info["fullname"].string
        avatarPicture = info["userpic_url"].url
    }
}

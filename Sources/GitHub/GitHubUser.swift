import Foundation
import SwiftyJSON

public final class GitHubUser: BaseUser {
    public required init?(info: JSON) {
        if let id = info["id"].idString {
            super.init(userId: id)
        } else {
            return nil
        }

        username = info["login"].string
        fullname = info["name"].string
        avatarPicture = info["avatar_url"].url
    }
}

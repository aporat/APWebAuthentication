import Foundation
import SwiftyJSON

public final class TwitchUser: GenericUser, @unchecked Sendable {
    public required init?(info: JSON) {
        guard let id = info["id"].string ?? info["_id"].string else {
            return nil
        }
        
        let username = info["login"].string ?? info["name"].string
        let fullname = info["display_name"].string
        let avatarPicture = info["profile_image_url"].url ?? info["logo"].url

        super.init(userId: id,
                   username: username,
                   fullname: fullname,
                   avatarPicture: avatarPicture)
    }
}

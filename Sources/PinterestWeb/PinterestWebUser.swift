import Foundation
import SwiftyJSON

public final class PinterestWebUser: GenericUser, @unchecked Sendable {
    public required init?(info: JSON) {
        guard let id = info["id"].idString else {
            return nil
        }
        let username = info["username"].string
        let fullname = info["full_name"].string
        let avatarPicture = info["image_medium_url"].url
        
        super.init(userId: id,
                   username: username,
                   fullname: fullname,
                   avatarPicture: avatarPicture)
    }
}

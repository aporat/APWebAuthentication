import Foundation
import SwiftyJSON

public final class RedditUser: GenericUser, @unchecked Sendable {
    public required init?(info: JSON) {
        guard let id = info["id"].string else {
            return nil
        }
        
        let name = info["name"].string
        let avatarPicture = info["icon_img"].url
        let isVerified = info["verified"].boolValue
        
        super.init(userId: id,
                   username: name,
                   fullname: name,
                   avatarPicture: avatarPicture,
                   privateProfile: false,
                   verified: isVerified)
    }
}

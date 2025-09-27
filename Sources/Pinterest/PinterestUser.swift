import Foundation
import SwiftyJSON

public final class PinterestUser: GenericUser, @unchecked Sendable {
    public required init?(info: JSON) {
        guard let id = info["id"].idString ?? info["username"].idString else {
            return nil
        }
        
        let username = info["username"].string
        let avatarPicture = info["profile_image"].url
        
        let constructedFullname: String?
        if let firstName = info["first_name"].string, let lastName = info["last_name"].string {
            constructedFullname = firstName + " " + lastName
        } else {
            constructedFullname = nil
        }

        super.init(userId: id,
                   username: username,
                   fullname: constructedFullname,
                   avatarPicture: avatarPicture)
    }
}

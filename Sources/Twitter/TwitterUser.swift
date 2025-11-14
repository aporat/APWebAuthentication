import Foundation
import SwiftyJSON

public final class TwitterUser: GenericUser, @unchecked Sendable {
    public required init?(info: JSON) {
        guard let id = info["id_str"].string ?? info["id"].number?.stringValue else {
            return nil
        }
        
        let username = info["screen_name"].string
        let fullname = info["name"].string
        let isVerified = info["verified"].boolValue
        let privateProfile = info["protected"].boolValue
        
        let constructedAvatarPicture: URL?
        if let pictureString = info["profile_image_url_https"].string {
            let biggerPictureString = pictureString.replacingOccurrences(of: "_normal", with: "")
            constructedAvatarPicture = URL(string: biggerPictureString)
        } else {
            constructedAvatarPicture = nil
        }
        
        super.init(userId: id,
                   username: username,
                   fullname: fullname,
                   avatarPicture: constructedAvatarPicture,
                   privateProfile: privateProfile,
                   verified: isVerified)
    }
}

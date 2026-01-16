import Foundation
@preconcurrency import SwiftyJSON

// MARK: - TwitterUser

public final class TwitterUser: GenericUser, @unchecked Sendable {
    
    // MARK: - Initialization
    
    public required init?(info: JSON) {
        // Extract user ID (string or number format)
        guard let id = info["id_str"].string ?? info["id"].number?.stringValue else {
            return nil
        }
        
        // Extract profile information
        let username = info["screen_name"].string
        let fullname = info["name"].string
        let isVerified = info["verified"].boolValue
        let privateProfile = info["protected"].boolValue
        
        // Process avatar URL (remove '_normal' suffix for higher quality)
        let constructedAvatarPicture: URL?
        if let pictureString = info["profile_image_url_https"].string {
            let biggerPictureString = pictureString.replacingOccurrences(of: "_normal", with: "")
            constructedAvatarPicture = URL(string: biggerPictureString)
        } else {
            constructedAvatarPicture = nil
        }
        
        super.init(
            userId: id,
            username: username,
            fullname: fullname,
            avatarPicture: constructedAvatarPicture,
            privateProfile: privateProfile,
            verified: isVerified
        )
    }
}

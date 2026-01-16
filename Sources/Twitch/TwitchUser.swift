import Foundation
@preconcurrency import SwiftyJSON

// MARK: - TwitchUser

public final class TwitchUser: GenericUser, @unchecked Sendable {
    
    // MARK: - Initialization
    
    public required init?(info: JSON) {
        // Extract user ID (try modern 'id' field first, fallback to legacy '_id')
        guard let id = info["id"].string ?? info["_id"].string else {
            return nil
        }
        
        // Extract profile information (Helix API vs older API formats)
        let username = info["login"].string ?? info["name"].string
        let fullname = info["display_name"].string
        let avatarPicture = info["profile_image_url"].url ?? info["logo"].url
        
        super.init(
            userId: id,
            username: username,
            fullname: fullname,
            avatarPicture: avatarPicture
        )
    }
}

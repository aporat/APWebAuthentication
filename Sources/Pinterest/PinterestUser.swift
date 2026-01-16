import Foundation
@preconcurrency import SwiftyJSON

// MARK: - PinterestUser

public final class PinterestUser: GenericUser, @unchecked Sendable {
    
    // MARK: - Initialization
    
    public required init?(info: JSON) {
        // Extract user ID (try 'id' first, fallback to 'username')
        guard let id = info["id"].idString ?? info["username"].idString else {
            return nil
        }
        
        // Extract basic profile information
        let username = info["username"].string
        let avatarPicture = info["profile_image"].url
        
        // Construct full name from available fields
        let constructedFullname: String?
        if let fullname = info["display_name"].string {
            // Use display_name if available
            constructedFullname = fullname
        } else if let firstName = info["first_name"].string, let lastName = info["last_name"].string {
            // Combine first and last name
            constructedFullname = "\(firstName) \(lastName)"
        } else {
            constructedFullname = nil
        }

        super.init(
            userId: id,
            username: username,
            fullname: constructedFullname,
            avatarPicture: avatarPicture
        )
    }
}

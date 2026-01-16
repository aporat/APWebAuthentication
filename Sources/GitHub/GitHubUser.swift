import Foundation
@preconcurrency import SwiftyJSON

// MARK: - GitHubUser

public final class GitHubUser: GenericUser, @unchecked Sendable {
    
    // MARK: - Initialization
    
    public required init?(info: JSON) {
        // Extract user ID (can be string or number)
        let id = info["id"].string ?? info["id"].number?.stringValue
        
        guard let id = id else {
            return nil
        }
        
        // Extract user profile information
        let username = info["login"].string
        let fullname = info["name"].string
        let avatarPicture = info["avatar_url"].url

        super.init(
            userId: id,
            username: username,
            fullname: fullname,
            avatarPicture: avatarPicture
        )
        
        // Set social metrics
        followersCount = info["followers"].int32
        followingCount = info["following"].int32
    }
}

import Foundation
@preconcurrency import SwiftyJSON

public final class GitHubUser: GenericUser, @unchecked Sendable {
    public required init?(info: JSON) {
        let id = info["id"].string ?? info["id"].number?.stringValue
        
        guard let id = id else {
            return nil
        }
        
        let username = info["login"].string
        let fullname = info["name"].string
        let avatarPicture = info["avatar_url"].url

        super.init(userId: id,
                   username: username,
                   fullname: fullname,
                   avatarPicture: avatarPicture)
        
        followersCount = info["followers"].int32
        followingCount = info["following"].int32
    }
}

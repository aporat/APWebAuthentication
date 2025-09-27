import Foundation
import SwiftyJSON

public final class GitHubUser: GenericUser, @unchecked Sendable {
    public required init?(info: JSON) {
        guard let id = info["id"].number?.stringValue else {
            return nil
        }
        
        let username = info["login"].string
        let fullname = info["name"].string
        let avatarPicture = info["avatar_url"].url

        super.init(userId: id,
                   username: username,
                   fullname: fullname,
                   avatarPicture: avatarPicture)
    }
}

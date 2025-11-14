import Foundation
import SwiftyJSON

public final class TikTokWebUser: GenericUser, @unchecked Sendable {
    public required init?(info: JSON) {
        let id = info["uid"].string ?? info["id"].string ?? info["userId"].string ?? info["sec_uid"].string
        
        guard let userId = id else {
            return nil
        }
        
        let username = info["unique_id"].string ?? info["uniqueId"].string
        let fullname = info["nickname"].string ?? info["nickName"].string
        
        let avatarPicture: URL?
        if let thumbURL = info["avatarThumb"].url {
            avatarPicture = thumbURL
        } else if let mediumURL = info["avatarMedium"].url {
            avatarPicture = mediumURL
        } else if let firstURL = info["avatar_thumb"]["url_list"].array?.first?.url {
            avatarPicture = firstURL
        } else if let firstCoverURL = info["coversMedium"].array?.first?.url {
            avatarPicture = firstCoverURL
        } else {
            avatarPicture = nil
        }
        
        super.init(userId: userId,
                   username: username,
                   fullname: fullname,
                   avatarPicture: avatarPicture)
    }
}

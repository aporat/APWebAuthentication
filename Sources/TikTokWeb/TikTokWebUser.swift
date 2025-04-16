import Foundation
import SwiftyJSON

public final class TikTokWebUser: BaseUser {
    public required init?(info: JSON) {
        if let id = info["uid"].idString {
            super.init(userId: id)
        } else if let id = info["id"].idString {
            super.init(userId: id)
        } else if let id = info["userId"].idString {
            super.init(userId: id)
        } else if let id = info["sec_uid"].idString { // comments dont have user id
            super.init(userId: id)
        } else {
            return nil
        }

        if let value = info["unique_id"].string {
            username = value
        } else if let value = info["uniqueId"].string {
            username = value
        }

        if let value = info["nickname"].string {
            fullname = value
        } else if let value = info["nickName"].string {
            fullname = value
        }

        if info["avatarThumb"].exists() {
            avatarPicture = info["avatarThumb"].url
        } else if info["avatarMedium"].exists() {
            avatarPicture = info["avatarMedium"].url
        } else if info["avatar_thumb"]["url_list"].exists() {
            avatarPicture = info["avatar_thumb"]["url_list"].arrayValue.first?.url
        } else if info["coversMedium"].exists() {
            avatarPicture = info["coversMedium"].arrayValue.first?.url
        }
    }
}

import Foundation
import SwiftyJSON

public final class TumblrBlog: BaseUser {
    public var name: String?
    public var postsCount: Int32 = 0

    public required init?(info: JSON) {
        if let uuid = info["uuid"].string {
            super.init(userId: uuid)
        } else {
            return nil
        }

        postsCount = info["posts"].int32Number ?? 0

        if let url = info["url"].string {
           let url = url.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "www.tumblr.com/blog/view/", with: "").replacingOccurrences(of: "tumblr.com/", with: "tumblr.com")
            username = url
       }
        
        if let currentName = info["name"].string {
            fullname = currentName
        } else if let currentName = info["title"].string {
            fullname = currentName
        }

        followersCount = info["followers"].int32Number ?? 0
        avatarPicture = URL(string: String(format: "https://api.tumblr.com/v2/blog/%@/avatar", userId))
    }
}

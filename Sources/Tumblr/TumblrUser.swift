import SwiftyJSON
import Foundation

public final class TumblrUser: BaseUser {
    public var blogs = [TumblrBlog]()

    public required init?(info: JSON) {
        if let id = info["name"].string {
            super.init(userId: id)
            username = id
            fullname = id
        } else {
            return nil
        }

        for blogData in info["blogs"].arrayValue {
            if let blog = TumblrBlog(info: blogData) {
                blogs.append(blog)
            }
        }
    }
}

import Foundation
import SwiftyJSON

public final class TumblrBlog: GenericUser, @unchecked Sendable {
    
    /// The display name of the blog, which may differ from the username/URL.
    public var name: String?
    
    /// The total number of posts on the blog.
    public var postsCount: Int32 = 0

    /// A failable initializer that creates a `TumblrBlog` from a SwiftyJSON object.
    /// - Parameter info: The JSON object containing the blog's data.
    public required init?(info: JSON) {
        guard let uuid = info["uuid"].string, !uuid.isEmpty else {
            return nil
        }
        
        let username = Self.parseUsername(from: info["url"].string)
        let fullname = info["name"].string ?? info["title"].string
        let avatarURL = URL(string: "https://api.tumblr.com/v2/blog/\(uuid)/avatar")

        super.init(userId: uuid,
                   username: username,
                   fullname: fullname,
                   avatarPicture: avatarURL)
        
        self.postsCount = info["posts"].int32 ?? 0
        self.followersCount = info["followers"].int32 ?? 0
    }
    
    /// A helper function to parse the blog's username from its URL string.
    private static func parseUsername(from urlString: String?) -> String? {
        guard let urlString else { return nil }
        
        return urlString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.tumblr.com/blog/view/", with: "")
            .replacingOccurrences(of: "tumblr.com/", with: "tumblr.com")
    }
}

import Foundation
import SwiftyJSON

public final class TumblrBlog: BaseUser, Sendable {
    
    /// The display name of the blog, which may differ from the username/URL.
    public var name: String?
    
    /// The total number of posts on the blog.
    public var postsCount: Int32 = 0

    /// A failable initializer that creates a `TumblrBlog` from a SwiftyJSON object.
    /// - Parameter info: The JSON object containing the blog's data.
    public required init?(info: JSON) {
        // 1. Use a `guard` statement for a clear, early exit if the required `uuid` is missing.
        guard let uuid = info["uuid"].string, !uuid.isEmpty else {
            return nil
        }
        
        super.init(userId: uuid)

        // 2. Use modern patterns for cleaner property assignment.
        self.postsCount = info["posts"].int32Number ?? 0
        self.followersCount = info["followers"].int32Number ?? 0
        
        // Use the nil-coalescing operator to fall back from "name" to "title".
        self.fullname = info["name"].string ?? info["title"].string
        
        // 3. Encapsulate the complex URL parsing logic in a private helper method for clarity.
        self.username = Self.parseUsername(from: info["url"].string)
        
        // Construct the avatar URL safely.
        self.avatarPicture = URL(string: "https://api.tumblr.com/v2/blog/\(userId)/avatar")
    }
    
    /// A helper function to parse the blog's username from its URL string.
    private static func parseUsername(from urlString: String?) -> String? {
        guard let urlString else { return nil }
        
        // This chains the replacements from the original code in a more readable way.
        return urlString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.tumblr.com/blog/view/", with: "")
            .replacingOccurrences(of: "tumblr.com/", with: "tumblr.com") // This seems intentional to handle a specific format
    }
}

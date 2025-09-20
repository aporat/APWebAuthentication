import Foundation
import SwiftyJSON

/// A concrete user model for a Tumblr user, including their blogs.
public final class TumblrUser: BaseUser, Sendable {

    /// A list of the user's blogs.
    public var blogs = [TumblrBlog]()

    /// A failable initializer that creates a `TumblrUser` from a SwiftyJSON object.
    /// - Parameter info: The JSON object containing the user's data.
    public required init?(info: JSON) {
        guard let id = info["name"].string, !id.isEmpty else {
            return nil
        }
        
        super.init(userId: id)
        
        // Set the properties on the instance.
        self.username = id
        self.fullname = id
        
        self.blogs = info["blogs"].arrayValue.compactMap { TumblrBlog(info: $0) }
    }
}

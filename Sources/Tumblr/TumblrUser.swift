import Foundation
import SwiftyJSON

/// A concrete user model for a Tumblr user, including their blogs.
public final class TumblrUser: User, Sendable {

    public let userId: String
    public let username: String?
    public let fullname: String?
    public let avatarPicture: URL? = nil
    public let privateProfile: Bool = false
    public let verified: Bool = false
    
    /// A list of the user's blogs.
    public var blogs = [TumblrBlog]()

    /// A failable initializer that creates a `TumblrUser` from a SwiftyJSON object.
    /// - Parameter info: The JSON object containing the user's data.
    public required init?(info: JSON) {
        if let id = info["name"].idString {
            userId = id
        } else {
            return nil
        }
        
        self.username = userId
        self.fullname = userId
        
        self.blogs = info["blogs"].arrayValue.compactMap { TumblrBlog(info: $0) }
    }
}

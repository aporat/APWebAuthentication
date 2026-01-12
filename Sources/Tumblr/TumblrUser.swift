import Foundation
@preconcurrency import SwiftyJSON

public final class TumblrUser: User, Sendable {
    
    public let userId: String
    public let username: String?
    public let fullname: String?
    public let avatarPicture: URL? = nil
    public let privateProfile: Bool = false
    public let verified: Bool = false
    
    /// A list of the user's blogs.
    public let blogs: [TumblrBlog]
    
    /// A failable initializer that creates a `TumblrUser` from a SwiftyJSON object.
    /// - Parameter info: The JSON object containing the user's data.
    public required init?(info: JSON) {
        guard let name = info["name"].string else {
            return nil
        }
        
        self.userId = name
        self.username = name
        self.fullname = name
        self.blogs = info["blogs"].arrayValue.compactMap { TumblrBlog(info: $0) }
    }
}

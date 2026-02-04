import Foundation
@preconcurrency import SwiftyJSON

// MARK: - TumblrUser

public final class TumblrUser: User, Sendable {

    // MARK: - Properties

    public let userId: String
    public let username: String?
    public let fullname: String?
    public let avatarPicture: URL? = nil
    public let privateProfile: Bool = false
    public let verified: Bool = false

    /// The user's blogs (Tumblr accounts can have multiple blogs)
    public let blogs: [TumblrBlog]

    // MARK: - Initialization

    /// Creates a Tumblr user from JSON data
    /// - Parameter info: The JSON object containing user data
    public required init?(info: JSON) {
        // Extract username (used as both ID and username)
        guard let name = info["name"].string else {
            return nil
        }

        self.userId = name
        self.username = name
        self.fullname = name

        // Parse user's blogs
        self.blogs = info["blogs"].arrayValue.compactMap { TumblrBlog(info: $0) }
    }
}

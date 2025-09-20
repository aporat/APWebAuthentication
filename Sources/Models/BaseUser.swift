import Foundation

open class BaseUser: User, Hashable, Sendable {
    public var userId: String
    public var username: String?
    public var fullname: String?
    public var avatarPicture: URL?

    // user info
    public var privateProfile = false
    public var verified = false
    public var followersCount: Int32?
    public var followingCount: Int32?
    public var mediaCount: Int32?
    public var likesCount: Int32?

    open func hash(into hasher: inout Hasher) {
        hasher.combine(userId.hashValue)
    }

    public init?(userId: String) {
        self.userId = userId
    }

    public convenience init?(_ userId: String, username: String? = nil, fullname: String? = nil, avatarPicture: URL? = nil) {
        self.init(userId: userId)

        self.username = username
        self.avatarPicture = avatarPicture
        self.fullname = fullname
    }

    public static func == (lhs: BaseUser, rhs: BaseUser) -> Bool {
        lhs.userId == rhs.userId
    }

    public var description: String {
        userId
    }
}

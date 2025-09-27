import Foundation

open class GenericUser: User, Hashable, @unchecked Sendable {
    public let userId: String
    public let username: String?
    public let fullname: String?
    public let avatarPicture: URL?
    public let privateProfile: Bool
    public let verified: Bool
    public var followersCount: Int32?
    public var followingCount: Int32?
    public var mediaCount: Int32?
    public var likesCount: Int32?
    
    open func hash(into hasher: inout Hasher) {
        hasher.combine(userId.hashValue)
    }
    
    public init(userId: String, username: String?, fullname: String? = nil, avatarPicture: URL? = nil, privateProfile: Bool = false, verified: Bool = false) {
        self.userId = userId
        self.username = username
        self.fullname = fullname
        self.avatarPicture = avatarPicture
        self.privateProfile = privateProfile
        self.verified = verified
    }
    
    public convenience init(userId: String) {
        self.init(userId: userId, username: nil, fullname: nil, avatarPicture: nil)
    }
    
    public static func == (lhs: GenericUser, rhs: GenericUser) -> Bool {
        lhs.userId == rhs.userId
    }
    
    public var description: String {
        userId
    }
}

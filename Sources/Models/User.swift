import CoreData

public protocol User {
    var userId: String { get set }
    var username: String? { get set }
    var avatarPicture: URL? { get set }
    var fullname: String? { get set }
    var privateProfile: Bool { get set }
    var verified: Bool { get set }
}

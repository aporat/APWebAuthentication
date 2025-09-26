import Foundation

public protocol User: Sendable {
    var userId: String { get }
    var username: String? { get }
    var fullname: String? { get }
    var avatarPicture: URL? { get }
    var privateProfile: Bool { get }
    var verified: Bool { get }
}

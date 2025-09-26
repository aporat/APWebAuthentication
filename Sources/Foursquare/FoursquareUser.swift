import Foundation
import SwiftyJSON

public final class FoursquareUser: User, Sendable {
    public let userId: String
    public let username: String?
    public let fullname: String?
    public let avatarPicture: URL?
    public let privateProfile: Bool = false
    public let verified: Bool = false
    
    public required init?(info: JSON) {
        if let id = info["id"].idString {
            userId = id
        } else {
            return nil
        }
        
        self.username = info["homeCity"].string
        
        if let firstName = info["firstName"].string, let lastName = info["lastName"].string {
            fullname = firstName + " " + lastName
        } else {
            fullname = nil
        }
        
        if let photoPrefix = info["photo"]["prefix"].string, let photoSuffix = info["photo"]["suffix"].string {
            avatarPicture = URL(string: photoPrefix + "110x110" + photoSuffix)
        } else {
            avatarPicture = nil
        }
    }
}

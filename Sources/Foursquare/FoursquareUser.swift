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
        guard let id = info["id"].idString else {
            return nil
        }
        
        let homeCity = info["homeCity"].string
        
        let constructedFullname: String?
        if let firstName = info["firstName"].string, let lastName = info["lastName"].string {
            constructedFullname = firstName + " " + lastName
        } else {
            constructedFullname = nil
        }
        
        let constructedAvatarPicture: URL?
        if let photoPrefix = info["photo"]["prefix"].string, let photoSuffix = info["photo"]["suffix"].string {
            constructedAvatarPicture = URL(string: photoPrefix + "110x110" + photoSuffix)
        } else {
            constructedAvatarPicture = nil
        }
        
        self.userId = id
        self.username = homeCity
        self.fullname = constructedFullname
        self.avatarPicture = constructedAvatarPicture
    }
}

import Foundation
import SwiftyJSON

public final class FoursquareUser: BaseUser, @unchecked Sendable {
    public required init?(info: JSON) {
        if let id = info["id"].idString {
            super.init(userId: id)
        } else {
            return nil
        }

        if let currentUsername = info["homeCity"].string {
            username = currentUsername
        }

        if let firstName = info["firstName"].string, let lastName = info["lastName"].string {
            fullname = firstName + " " + lastName
        }

        if let photoPrefix = info["photo"]["prefix"].string, let photoSuffix = info["photo"]["suffix"].string {
            avatarPicture = URL(string: photoPrefix + "110x110" + photoSuffix)
        }
    }
}

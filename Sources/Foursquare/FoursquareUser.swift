import Foundation
@preconcurrency import SwiftyJSON

// MARK: - FoursquareUser

/// Represents a Foursquare user profile.
///
/// Maps Foursquare API user data to the common User protocol.
/// Note: Foursquare doesn't provide traditional usernames, so homeCity is used instead.
public final class FoursquareUser: User, Sendable {

    // MARK: - Properties

    public let userId: String
    public let username: String?
    public let fullname: String?
    public let avatarPicture: URL?
    public let privateProfile: Bool = false
    public let verified: Bool = false

    // MARK: - Initialization

    /// Creates a FoursquareUser from API response JSON.
    ///
    /// - Parameter info: JSON response from Foursquare API
    /// - Returns: FoursquareUser instance, or nil if required fields are missing
    public required init?(info: JSON) {
        // Extract user ID (required)
        guard let id = info["id"].idString else {
            return nil
        }

        // Use homeCity as username (Foursquare doesn't have traditional usernames)
        let homeCity = info["homeCity"].string

        // Construct full name from first and last name
        let constructedFullname: String?
        if let firstName = info["firstName"].string,
           let lastName = info["lastName"].string {
            constructedFullname = "\(firstName) \(lastName)"
        } else {
            constructedFullname = nil
        }

        // Construct avatar URL from photo prefix and suffix
        // Format: prefix + size + suffix (e.g., "prefix110x110suffix")
        let constructedAvatarPicture: URL?
        if let photoPrefix = info["photo"]["prefix"].string,
           let photoSuffix = info["photo"]["suffix"].string {
            constructedAvatarPicture = URL(string: "\(photoPrefix)110x110\(photoSuffix)")
        } else {
            constructedAvatarPicture = nil
        }

        self.userId = id
        self.username = homeCity
        self.fullname = constructedFullname
        self.avatarPicture = constructedAvatarPicture
    }
}

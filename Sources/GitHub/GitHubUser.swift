import Foundation
@preconcurrency import SwiftyJSON

// MARK: - GitHubUser

public final class GitHubUser: GenericUser, @unchecked Sendable {

    // MARK: - Initialization

    public required init?(info: JSON) {
        let id = info["id"].stringValue
        guard !id.isEmpty else { return nil }

        super.init(
            userId: id,
            username: info["login"].string,
            fullname: info["name"].string,
            avatarPicture: info["avatar_url"].url
        )

        followersCount = info["followers"].int32
        followingCount = info["following"].int32
    }
}

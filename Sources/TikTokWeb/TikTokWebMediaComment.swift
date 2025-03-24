import SwiftyJSON
import UIKit

public final class TikTokWebMediaComment: MediaComment {
    public var commentId: String
    public var text: String?
    public var mediaId: String?
    public var dateTaken: Date
    public var user: User?

    public required init?(info: JSON) {
        if let id = info["cid"].idString {
            commentId = id
            dateTaken = info["create_time"].date ?? Date()
        } else {
            return nil
        }

        text = info["text"].string
        user = TikTokWebUser(info: info["user"])
    }
}

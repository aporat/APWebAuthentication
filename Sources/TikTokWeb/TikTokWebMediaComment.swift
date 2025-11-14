import Foundation
import SwiftyJSON

public final class TikTokWebMediaComment: MediaComment, Sendable {
    public let commentId: String
    public let text: String?
    public let mediaId: String?
    public let dateTaken: Date
    public let user: User?
    
    public required init?(info: JSON) {
        if let id = info["cid"].idString {
            commentId = id
            dateTaken = info["create_time"].date ?? Date()
        } else {
            return nil
        }
        
        mediaId = nil
        text = info["text"].string
        user = TikTokWebUser(info: info["user"])
    }
}

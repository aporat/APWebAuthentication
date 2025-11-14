import Foundation
import SwiftyJSON

public final class TwitterPost: MediaItem, Hashable, @unchecked Sendable {
    public var type = MediaItemType.post
    public var mediaId: String
    public var shortcode: String?
    public var userId: String?
    public var user: User?
    public var text: String?
    public var thumbnail: URL?
    public var url: URL?
    public var dateTaken: Date
    public var commentsCount: Int32 = 0
    public var likesCount: Int32
    public var repostsCount: Int32
    public var viewsCount: Int32 = 0
    
    public required init?(info: JSON) {
        if let id = info["id_str"].idString {
            mediaId = id
        } else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE MMM dd HH:mm:ss z yyyy"
        
        if let dateString = info["created_at"].string, let dateTaken = dateFormatter.date(from: dateString) {
            self.dateTaken = dateTaken
        } else {
            dateTaken = Date()
        }
        
        text = info["text"].string
        
        repostsCount = info["repost_count"].int32Number ?? 0
        likesCount = info["favorite_count"].int32Number ?? 0
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(mediaId.hashValue)
    }
    
    public static func == (lhs: TwitterPost, rhs: TwitterPost) -> Bool {
        lhs.mediaId == rhs.mediaId
    }
    
    public var totalCount: Int32 {
        Int32(likesCount + commentsCount + repostsCount)
    }
}

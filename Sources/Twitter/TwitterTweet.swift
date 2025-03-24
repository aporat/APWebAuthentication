import SwiftyJSON
import Foundation

public final class TwitterTweet: MediaItem, Hashable {
    public var type = MediaItemType.tweet
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
    public var retweetsCount: Int32
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

        retweetsCount = info["retweet_count"].int32Number ?? 0
        likesCount = info["favorite_count"].int32Number ?? 0
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(mediaId.hashValue)
    }

    public static func == (lhs: TwitterTweet, rhs: TwitterTweet) -> Bool {
        lhs.mediaId == rhs.mediaId
    }

    public var totalCount: Int32 {
        Int32(likesCount + commentsCount + retweetsCount)
    }
}

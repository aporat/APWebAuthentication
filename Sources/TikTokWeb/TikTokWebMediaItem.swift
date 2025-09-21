import Foundation
import SwiftyJSON

public final class TikTokWebMediaItem: MediaItem, Hashable, @unchecked Sendable {
    public var type = MediaItemType.video
    public var mediaId: String
    public var shortcode: String?
    public var userId: String?
    public var thumbnail: URL?
    public var url: URL?
    public var dateTaken: Date
    public var commentsCount: Int32
    public var likesCount: Int32
    public var viewsCount: Int32
    public var user: User?
    public var text: String?

    public required init?(info: JSON) {
        if let id = info["id"].idString {
            mediaId = id
        } else {
            return nil
        }

        text = info["desc"].string
        dateTaken = info["createTime"].date ?? Date()
        userId = info["author"]["id"].idString

        if info["video"]["cover"].exists() {
            thumbnail = info["video"]["cover"].url
        }

        commentsCount = info["stats"]["commentCount"].int32Number ?? 0
        likesCount = info["stats"]["diggCount"].int32Number ?? 0
        viewsCount = info["stats"]["playCount"].int32Number ?? 0
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(mediaId.hashValue)
    }

    public static func == (lhs: TikTokWebMediaItem, rhs: TikTokWebMediaItem) -> Bool {
        lhs.mediaId == rhs.mediaId
    }

    public var totalCount: Int32 {
        Int32(likesCount + commentsCount)
    }
}

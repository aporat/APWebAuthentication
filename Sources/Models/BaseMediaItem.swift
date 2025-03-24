import Foundation

open class BaseMediaItem: MediaItem, Hashable {
    public var type = MediaItemType.photo
    public var mediaId: String
    public var userId: String?
    public var shortcode: String?
    public var thumbnail: URL?
    public var url: URL?
    public var dateTaken = Date()
    public var commentsCount: Int32 = 0
    public var likesCount: Int32 = 0
    public var viewsCount: Int32 = 0
    public var user: User?
    public var text: String?

    open func hash(into hasher: inout Hasher) {
        hasher.combine(mediaId.hashValue)
    }

    public init?(mediaId: String) {
        self.mediaId = mediaId
    }

    public static func == (lhs: BaseMediaItem, rhs: BaseMediaItem) -> Bool {
        lhs.mediaId == rhs.mediaId
    }

    public var description: String {
        mediaId
    }

    public var totalCount: Int32 {
        Int32(likesCount + commentsCount)
    }
}

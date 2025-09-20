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
            hasher.combine(mediaId)
        }

    public init(mediaId: String, type: MediaItemType = .photo) {
         self.mediaId = mediaId
         self.type = type
     }

    public static func == (lhs: BaseMediaItem, rhs: BaseMediaItem) -> Bool {
        lhs.mediaId == rhs.mediaId
    }

    public var description: String {
            "\(type) MediaItem (ID: \(mediaId))"
        }

    public var totalCount: Int32 {
            likesCount + commentsCount
        }
}

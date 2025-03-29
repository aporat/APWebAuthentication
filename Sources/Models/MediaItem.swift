import SwiftyJSON
import Foundation

public enum MediaItemType: Int16 {
    case photo = 1
    case video = 2
    case album = 3
    case post = 4
}

public protocol MediaItem {
    var type: MediaItemType { get }
    var mediaId: String { get }
    var shortcode: String? { get }
    var userId: String? { get }
    var thumbnail: URL? { get }
    var url: URL? { get }
    var dateTaken: Date { get }
    var commentsCount: Int32 { get }
    var likesCount: Int32 { get }
    var viewsCount: Int32 { get }
    var user: User? { get }
    var text: String? { get }

    var totalCount: Int32 { get }
}

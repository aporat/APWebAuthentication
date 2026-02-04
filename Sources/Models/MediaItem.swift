import Foundation
@preconcurrency import SwiftyJSON

public enum MediaItemType: Int16, Sendable, CaseIterable, CustomStringConvertible {
    case photo = 1
    case video = 2
    case album = 3
    case post = 4

    /// Provides a human-readable name for the media type (e.g., "Photo").
    public var description: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        case .album: return "Album"
        case .post: return "Post"
        }
    }
}

/// A protocol that defines the essential properties for any media item in your app.
public protocol MediaItem: Sendable {
    var type: MediaItemType { get }
    var mediaId: String { get }
    var shortcode: String? { get }
    var userId: String? { get }
    var thumbnail: URL? { get }
    var url: URL? { get }
    var dateTaken: Date { get }
    var commentsCount: Int { get }
    var likesCount: Int { get }
    var viewsCount: Int { get }
    var user: User? { get }
    var text: String? { get }
    var totalCount: Int { get }
}

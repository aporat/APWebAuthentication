import SwiftyJSON
import Foundation

public protocol StoryItem {
    init?(info: JSON)

    var storyId: String { get }
    var byUser: BaseUser { get }
    var thumbnailURL: URL? { get }
    var shortcode: String? { get }
    var dateTaken: Date { get }
    var dateExpiring: Date? { get }
    var views: Int32 { get }
    var viewers: [BaseUser] { get }
}

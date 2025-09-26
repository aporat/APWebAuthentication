import Foundation
import SwiftyJSON

public protocol StoryItem: Sendable {
    init?(info: JSON)

    var storyId: String { get }
    var byUser: GenericUser { get }
    var thumbnailURL: URL? { get }
    var shortcode: String? { get }
    var dateTaken: Date { get }
    var dateExpiring: Date? { get }
    var views: Int32 { get }
    var viewers: [GenericUser] { get }
}

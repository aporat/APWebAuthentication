import Foundation
import SwiftyJSON

// MARK: - Tag Protocol

/// A protocol representing a tag (e.g., a hashtag) that can be initialized from a JSON object.
public protocol Tag: Sendable {
    var tagId: String { get }
    
    var title: String { get set }
    var mediaCount: Int32 { get set }

    /// A failable initializer to create a tag from a JSON object.
    init?(info: JSON)
}


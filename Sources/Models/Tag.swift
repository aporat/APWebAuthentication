import Foundation
import SwiftyJSON

public protocol Tag {
    var tagId: String { get set }
    var title: String { get set }
    var mediaCount: Int32 { get set }

    init?(info: JSON)
}

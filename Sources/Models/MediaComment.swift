import Foundation
import SwiftyJSON

public protocol MediaComment {
    init?(info: JSON)

    var commentId: String { get }
    var text: String? { get }
    var dateTaken: Date { get }
    var user: User? { get }
}

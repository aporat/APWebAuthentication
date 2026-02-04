@testable import APWebAuthentication
import SwiftyJSON
import XCTest

final class PinterestWebUserTests: XCTestCase {
    func testPinterestWebUserInit() {
        let json = JSON([
            "id": "222",
            "username": "webpin",
            "full_name": "Web Pin",
            "image_medium_url": "https://pinterest.com/image.jpg"
        ])

        let user = PinterestWebUser(info: json)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.userId, "222")
        XCTAssertEqual(user?.username, "webpin")
        XCTAssertEqual(user?.fullname, "Web Pin")
        XCTAssertEqual(user?.avatarPicture?.absoluteString, "https://pinterest.com/image.jpg")
    }
}

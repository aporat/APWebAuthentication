import XCTest
import SwiftyJSON
@testable import APWebAuthentication

final class PinterestUserTests: XCTestCase {
    func testPinterestUserInit() {
        let json = JSON([
            "id": "111",
            "username": "pinuser",
            "first_name": "Pin",
            "last_name": "User",
            "profile_image": "https://pinterest.com/profile.jpg"
        ])

        let user = PinterestUser(info: json)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.userId, "111")
        XCTAssertEqual(user?.username, "pinuser")
        XCTAssertEqual(user?.fullname, "Pin User")
        XCTAssertEqual(user?.avatarPicture?.absoluteString, "https://pinterest.com/profile.jpg")
    }
}

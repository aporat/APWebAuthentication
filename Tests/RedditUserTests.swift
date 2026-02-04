@testable import APWebAuthentication
import SwiftyJSON
import XCTest

final class RedditUserTests: XCTestCase {
    func testRedditUserInit() {
        let json = JSON([
            "id": "333",
            "name": "reddituser",
            "icon_img": "https://reddit.com/avatar.png"
        ])

        let user = RedditUser(info: json)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.userId, "333")
        XCTAssertEqual(user?.username, "reddituser")
        XCTAssertEqual(user?.fullname, "reddituser")
        XCTAssertEqual(user?.avatarPicture?.absoluteString, "https://reddit.com/avatar.png")
    }
}

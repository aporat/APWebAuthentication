@testable import APWebAuthentication
import SwiftyJSON
import XCTest

final class TumblrUserTests: XCTestCase {
    func testTumblrUserInit() {
        let blogJSON = JSON([
            "uuid": "abc123",
            "posts": 10,
            "url": "https://abc123.tumblr.com/",
            "name": "BlogName"
        ])

        let json = JSON([
            "name": "tumblruser",
            "blogs": [blogJSON]
        ])

        let user = TumblrUser(info: json)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.userId, "tumblruser")
        XCTAssertEqual(user?.blogs.first?.userId, "abc123")
        XCTAssertEqual(user?.blogs.first?.postsCount, 10)
    }
}

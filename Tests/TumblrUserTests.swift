@testable import APWebAuthentication
import SwiftyJSON
import XCTest

final class TumblrUserTests: XCTestCase {
    func testTumblrUserInit() {
        // Use plain [String: Any] for nested dict so SwiftyJSON can deserialize
        // the blogs array correctly. Passing a JSON struct inside an array causes
        // SwiftyJSON to produce an .unknown-typed element, making the array empty.
        let json = JSON([
            "name": "tumblruser",
            "blogs": [
                [
                    "uuid": "abc123",
                    "posts": 10,
                    "url": "https://abc123.tumblr.com/",
                    "name": "BlogName"
                ] as [String: Any]
            ]
        ])

        let user = TumblrUser(info: json)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.userId, "tumblruser")
        XCTAssertEqual(user?.blogs.first?.userId, "abc123")
        XCTAssertEqual(user?.blogs.first?.postsCount, 10)
    }
}

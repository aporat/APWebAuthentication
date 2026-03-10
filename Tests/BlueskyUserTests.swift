@testable import APWebAuthentication
import SwiftyJSON
import XCTest

final class BlueskyUserTests: XCTestCase {

    func testBlueskyUserInit() {
        let json = JSON([
            "did": "did:plc:abc123",
            "handle": "user.bsky.social",
            "displayName": "Alice",
            "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:abc123/bafkreiabcd@jpeg",
            "followersCount": 100,
            "followsCount": 50,
            "postsCount": 200
        ])

        let user = BlueskyUser(info: json)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.did, "did:plc:abc123")
        XCTAssertEqual(user?.handle, "user.bsky.social")
        XCTAssertEqual(user?.userId, "did:plc:abc123")
        XCTAssertEqual(user?.username, "user.bsky.social")
        XCTAssertEqual(user?.fullname, "Alice")
        XCTAssertNotNil(user?.avatarPicture)
        XCTAssertEqual(user?.followersCount, 100)
        XCTAssertEqual(user?.followingCount, 50)
        XCTAssertEqual(user?.postsCount, 200)
    }

    func testBlueskyUserInitMissingDID() {
        let json = JSON([
            "handle": "user.bsky.social",
            "displayName": "Alice"
        ])

        let user = BlueskyUser(info: json)
        XCTAssertNil(user)
    }

    func testBlueskyUserInitMinimal() {
        let json = JSON(["did": "did:plc:xyz789"])

        let user = BlueskyUser(info: json)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.did, "did:plc:xyz789")
        XCTAssertNil(user?.handle)
        XCTAssertNil(user?.fullname)
        XCTAssertNil(user?.avatarPicture)
    }
}

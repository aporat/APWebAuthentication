@testable import APWebAuthentication
import SwiftyJSON
import XCTest

final class BlueskyUserTests: XCTestCase {

    func testInit_parsesProfileView() throws {
        let user = try XCTUnwrap(BlueskyUser(info: JSON([
            "did": "did:plc:abc123",
            "handle": "alice.bsky.social",
            "displayName": "  Alice  ",
            "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:abc123/x@jpeg",
            "followersCount": 1200,
            "followsCount": 340,
            "postsCount": 56,
            "viewer": [
                "following": "at://did:plc:me/app.bsky.graph.follow/3kabc",
                "followedBy": "at://did:plc:abc123/app.bsky.graph.follow/3kdef"
            ]
        ])))

        XCTAssertEqual(user.userId, "did:plc:abc123")
        XCTAssertEqual(user.username, "alice.bsky.social")
        XCTAssertEqual(user.fullname, "Alice")
        XCTAssertEqual(user.avatarPicture?.absoluteString, "https://cdn.bsky.app/img/avatar/plain/did:plc:abc123/x@jpeg")
        XCTAssertEqual(user.followersCount, 1200)
        XCTAssertEqual(user.followingCount, 340)
        XCTAssertEqual(user.mediaCount, 56)
        XCTAssertEqual(user.followURI, "at://did:plc:me/app.bsky.graph.follow/3kabc")
        XCTAssertTrue(user.isFollowingMe)
        XCTAssertFalse(user.isBlocked)
        XCTAssertFalse(user.isBlockingMe)
    }

    func testInit_minimalProfileViewBasic() throws {
        let user = try XCTUnwrap(BlueskyUser(info: JSON(["did": "did:plc:abc", "handle": "bob.bsky.social"])))

        XCTAssertEqual(user.userId, "did:plc:abc")
        XCTAssertNil(user.fullname)
        XCTAssertNil(user.followersCount)
        XCTAssertNil(user.followURI)
        XCTAssertFalse(user.isFollowingMe)
    }

    func testInit_emptyDisplayNameBecomesNil() throws {
        let user = try XCTUnwrap(BlueskyUser(info: JSON(["did": "did:plc:abc", "handle": "bob.bsky.social", "displayName": "   "])))
        XCTAssertNil(user.fullname)
    }

    func testInit_returnsNilWithoutDID() {
        XCTAssertNil(BlueskyUser(info: JSON(["handle": "nobody.bsky.social"])))
        XCTAssertNil(BlueskyUser(info: JSON(["did": "not-a-did"])))
    }

    func testEquality_isByDID() throws {
        let a = try XCTUnwrap(BlueskyUser(info: JSON(["did": "did:plc:abc", "handle": "old.bsky.social"])))
        let b = try XCTUnwrap(BlueskyUser(info: JSON(["did": "did:plc:abc", "handle": "new.bsky.social"])))
        XCTAssertEqual(a, b)
        XCTAssertEqual(Set([a, b]).count, 1)
    }

    func testRecordKey_parsesATURI() {
        XCTAssertEqual(BlueskyUser.recordKey(fromATURI: "at://did:plc:me/app.bsky.graph.follow/3kabc"), "3kabc")
        XCTAssertNil(BlueskyUser.recordKey(fromATURI: "https://bsky.app/profile/x"))
        XCTAssertNil(BlueskyUser.recordKey(fromATURI: "at://did:plc:me/app.bsky.graph.follow/"))
        XCTAssertNil(BlueskyUser.recordKey(fromATURI: "at://did:plc:me"))
    }
}

// MARK: - Scope

final class BlueskyScopeTests: XCTestCase {

    func testDefaultScope_isLeastPrivilegeAndDeclaresTheAppViewAudience() {
        let scopes = BlueskyAPIClient.defaultScope.split(separator: " ").map(String.init)

        XCTAssertEqual(scopes, [
            "atproto",
            "include:app.bsky.authViewAll?aud=did:web:api.bsky.app%23bsky_appview",
            "repo:app.bsky.graph.follow?action=create&action=delete"
        ])
        XCTAssertFalse(BlueskyAPIClient.defaultScope.contains("transition:generic"))
    }
}

@testable import APWebAuthentication
import SwiftyJSON
import XCTest

final class MastodonUserTests: XCTestCase {

    func testInit_parsesAccount() throws {
        let user = try XCTUnwrap(MastodonUser(info: JSON([
            "id": "109372849",
            "username": "alice",
            "acct": "alice",
            "display_name": "  Alice  ",
            "locked": true,
            "bot": false,
            "url": "https://mastodon.social/@alice",
            "avatar": "https://files.mastodon.social/avatars/alice.png",
            "followers_count": 1200,
            "following_count": 340,
            "statuses_count": 56
        ]), host: "mastodon.social"))

        XCTAssertEqual(user.userId, "109372849")
        XCTAssertEqual(user.username, "alice@mastodon.social")
        XCTAssertEqual(user.fullname, "Alice")
        XCTAssertTrue(user.privateProfile)
        XCTAssertFalse(user.isBot)
        XCTAssertEqual(user.profileURL?.absoluteString, "https://mastodon.social/@alice")
        XCTAssertEqual(user.avatarPicture?.absoluteString, "https://files.mastodon.social/avatars/alice.png")
        XCTAssertEqual(user.followersCount, 1200)
        XCTAssertEqual(user.followingCount, 340)
        XCTAssertEqual(user.mediaCount, 56)
    }

    func testInit_remoteAcctKeepsItsOwnDomain() throws {
        let user = try XCTUnwrap(MastodonUser(info: JSON([
            "id": "42",
            "username": "bob",
            "acct": "bob@fosstodon.org"
        ]), host: "mastodon.social"))

        XCTAssertEqual(user.username, "bob@fosstodon.org")
    }

    func testInit_withoutHostLeavesAcctAlone() throws {
        let user = try XCTUnwrap(MastodonUser(info: JSON(["id": "42", "acct": "bob"])))
        XCTAssertEqual(user.username, "bob")
    }

    func testInit_emptyDisplayNameBecomesNil() throws {
        let user = try XCTUnwrap(MastodonUser(info: JSON(["id": "42", "acct": "bob", "display_name": "   "]), host: "mastodon.social"))
        XCTAssertNil(user.fullname)
    }

    func testInit_hiddenCountsBecomeNil() throws {
        let user = try XCTUnwrap(MastodonUser(info: JSON(["id": "42", "acct": "bob", "followers_count": -1, "following_count": 7]), host: "mastodon.social"))
        XCTAssertNil(user.followersCount)
        XCTAssertEqual(user.followingCount, 7)
    }

    func testInit_fallsBackToStaticAvatar() throws {
        let user = try XCTUnwrap(MastodonUser(info: JSON(["id": "42", "acct": "bob", "avatar_static": "https://example.org/a.png"]), host: "mastodon.social"))
        XCTAssertEqual(user.avatarPicture?.absoluteString, "https://example.org/a.png")
    }

    func testInit_returnsNilWithoutId() {
        XCTAssertNil(MastodonUser(info: JSON(["acct": "nobody"]), host: "mastodon.social"))
        XCTAssertNil(MastodonUser(info: JSON(["id": ""]), host: "mastodon.social"))
    }

    func testEquality_isById() throws {
        let a = try XCTUnwrap(MastodonUser(info: JSON(["id": "42", "acct": "old"]), host: "mastodon.social"))
        let b = try XCTUnwrap(MastodonUser(info: JSON(["id": "42", "acct": "new"]), host: "mastodon.social"))
        XCTAssertEqual(a, b)
        XCTAssertEqual(Set([a, b]).count, 1)
    }

    // MARK: - Relationship

    func testRelationship_parsesFlags() throws {
        let relationship = try XCTUnwrap(MastodonRelationship(info: JSON([
            "id": "42",
            "following": true,
            "followed_by": false,
            "requested": true,
            "blocking": false,
            "blocked_by": true
        ])))

        XCTAssertEqual(relationship.userId, "42")
        XCTAssertTrue(relationship.following)
        XCTAssertFalse(relationship.followedBy)
        XCTAssertTrue(relationship.requested)
        XCTAssertFalse(relationship.blocking)
        XCTAssertTrue(relationship.blockedBy)
    }

    func testRelationship_returnsNilWithoutId() {
        XCTAssertNil(MastodonRelationship(info: JSON(["following": true])))
    }
}

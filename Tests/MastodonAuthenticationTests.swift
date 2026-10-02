@testable import APWebAuthentication
import SwiftyJSON
import XCTest

@MainActor
final class MastodonAuthenticationTests: XCTestCase {

    var auth: MastodonAuthentication!

    override func setUp() async throws {
        try await super.setUp()
        auth = MastodonAuthentication()
        auth.accountIdentifier = UUID().uuidString
    }

    override func tearDown() async throws {
        await auth.delete()
        try await super.tearDown()
    }

    func testIsAuthorized_needsTokenAndHost() {
        XCTAssertFalse(auth.isAuthorized)

        auth.accessToken = "token"
        XCTAssertFalse(auth.isAuthorized)

        auth.instanceHost = "mastodon.social"
        XCTAssertTrue(auth.isAuthorized)
    }

    func testInstanceURL() {
        XCTAssertNil(auth.instanceURL)
        auth.instanceHost = "mastodon.social"
        XCTAssertEqual(auth.instanceURL?.absoluteString, "https://mastodon.social")
    }

    func testConfigure_normalizesHost() {
        auth.configure(with: JSON(["host": "https://Fosstodon.org/@me", "client_id": "abc"]))
        XCTAssertEqual(auth.instanceHost, "fosstodon.org")
        XCTAssertEqual(auth.clientId, "abc")
    }

    func testConfigure_ignoresInvalidHost() {
        auth.instanceHost = "mastodon.social"
        auth.configure(with: JSON(["host": "not a host"]))
        XCTAssertEqual(auth.instanceHost, "mastodon.social")
    }

    func testDelete_clearsHost() async {
        auth.accessToken = "token"
        auth.instanceHost = "mastodon.social"
        await auth.delete()

        XCTAssertNil(auth.accessToken)
        XCTAssertNil(auth.instanceHost)
    }
}

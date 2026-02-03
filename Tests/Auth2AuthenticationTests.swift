import XCTest
@testable import APWebAuthentication

@MainActor
final class Auth2AuthenticationTests: XCTestCase {

    var auth: Auth2Authentication!

    override func setUp() {
        super.setUp()
        auth = Auth2Authentication()
        auth.accountIdentifier = UUID().uuidString
    }

    override func tearDown() async throws {
        await auth.delete()
        try await super.tearDown()
    }

    func testIsAuthorized_whenAccessTokenMissing_returnsFalse() {
        XCTAssertFalse(auth.isAuthorized)

        auth.accessToken = ""
        XCTAssertFalse(auth.isAuthorized)
    }

    func testIsAuthorized_whenAccessTokenPresent_returnsTrue() {
        auth.accessToken = "valid_token"
        XCTAssertTrue(auth.isAuthorized)
    }

    func testStoreAndLoad() async {
        auth.accessToken = "testAccessToken"
        auth.clientId = "testClientId"
        await auth.save()

        let loaded = Auth2Authentication()
        loaded.accountIdentifier = auth.accountIdentifier
        await loaded.load()

        XCTAssertEqual(loaded.accessToken, "testAccessToken")
        XCTAssertEqual(loaded.clientId, "testClientId")
        XCTAssertTrue(loaded.isAuthorized)
    }

    func testDelete_removesValues() async {
        auth.accessToken = "someToken"
        auth.clientId = "someClient"
        await auth.delete()

        XCTAssertNil(auth.accessToken)
        XCTAssertNil(auth.clientId)
    }
}

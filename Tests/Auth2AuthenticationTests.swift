import XCTest
@testable import APWebAuthentication

final class Auth2AuthenticationTests: XCTestCase {

    var auth: Auth2Authentication!

    override func setUp() {
        super.setUp()
        auth = Auth2Authentication()
        auth.accountIdentifier = UUID().uuidString
    }

    override func tearDown() {
        auth.clearAuthSettings()
        super.tearDown()
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

    func testStoreAndLoadAuthSettings() {
        auth.accessToken = "testAccessToken"
        auth.clientId = "testClientId"
        auth.storeAuthSettings()

        let loaded = Auth2Authentication()
        loaded.accountIdentifier = auth.accountIdentifier
        loaded.loadAuthSettings()

        XCTAssertEqual(loaded.accessToken, "testAccessToken")
        XCTAssertEqual(loaded.clientId, "testClientId")
        XCTAssertTrue(loaded.isAuthorized)
    }

    func testClearAuthSettings_removesValues() {
        auth.accessToken = "someToken"
        auth.clientId = "someClient"
        auth.clearAuthSettings()

        XCTAssertNil(auth.accessToken)
        XCTAssertNil(auth.clientId)
    }
}

import XCTest
@testable import APWebAuthentication

final class Auth1AuthenticationTests: XCTestCase {

    var auth: Auth1Authentication!

    override func setUp() {
        super.setUp()
        auth = Auth1Authentication()
        auth.accountIdentifier = UUID().uuidString
    }

    override func tearDown() {
        auth.clearAuthSettings()
        super.tearDown()
    }

    func testIsAuthorized_whenEmpty_returnsFalse() {
        XCTAssertFalse(auth.isAuthorized)

        auth.token = "tokenOnly"
        XCTAssertFalse(auth.isAuthorized)
    }

    func testIsAuthorized_whenBothSet_returnsTrue() {
        auth.token = "abc"
        auth.secret = "xyz"
        XCTAssertTrue(auth.isAuthorized)
    }

    func testStoreAndLoadAuthSettings() {
        auth.token = "storedToken"
        auth.secret = "storedSecret"
        auth.storeAuthSettings()

        let loaded = Auth1Authentication()
        loaded.accountIdentifier = auth.accountIdentifier
        loaded.loadAuthSettings()

        XCTAssertEqual(loaded.token, "storedToken")
        XCTAssertEqual(loaded.secret, "storedSecret")
        XCTAssertTrue(loaded.isAuthorized)
    }

    func testClearAuthSettings_removesValues() {
        auth.token = "abc"
        auth.secret = "xyz"
        auth.clearAuthSettings()

        XCTAssertNil(auth.token)
        XCTAssertNil(auth.secret)
    }
}

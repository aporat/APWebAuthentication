@testable import APWebAuthentication
import XCTest

@MainActor
final class Auth1AuthenticationTests: XCTestCase {

    var auth: Auth1Authentication!

    override func setUp() {
        super.setUp()
        auth = Auth1Authentication()
        auth.accountIdentifier = UUID().uuidString
    }

    override func tearDown() async throws {
        await auth.delete()
        try await super.tearDown()
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

    func testDelete_removesValues() async {
        auth.token = "abc"
        auth.secret = "xyz"
        await auth.delete()

        XCTAssertNil(auth.token)
        XCTAssertNil(auth.secret)
    }
}

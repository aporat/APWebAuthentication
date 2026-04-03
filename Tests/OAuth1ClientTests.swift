@testable import APWebAuthentication
import SwiftyJSON
import XCTest

@MainActor
final class OAuth1ClientTests: XCTestCase {

    var auth: Auth1Authentication!
    var client: OAuth1Client!

    override func setUp() async throws {
        try await super.setUp()
        auth = Auth1Authentication()
        auth.consumerKey = "key123"
        auth.consumerSecret = "secret456"
        client = OAuth1Client(
            accountType: AccountStore.twitter,
            baseURLString: "https://api.example.com",
            auth: auth
        )
    }

    func testInit_setsBaseURL() {
        XCTAssertEqual(client.baseURLString, "https://api.example.com")
    }

    func testInit_setsSessionManager() {
        XCTAssertNotNil(client.sessionManager)
    }
}

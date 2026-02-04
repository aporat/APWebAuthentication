@testable import APWebAuthentication
import SwiftyJSON
import XCTest

@MainActor
final class OAuth1ClientTests: XCTestCase {

    var auth: Auth1Authentication!
    var client: OAuth1Client!

    override func setUp() {
        super.setUp()
        auth = Auth1Authentication()
        client = OAuth1Client(
            accountType: AccountStore.twitter,
            baseURLString: "https://api.example.com",
            consumerKey: "key123",
            consumerSecret: "secret456",
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

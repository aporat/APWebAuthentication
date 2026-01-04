import XCTest
import Alamofire
import CryptoKit
@testable import APWebAuthentication

final class AuthClientTests: XCTestCase {

    var client: AuthClient!

    override func setUp() {
        super.setUp()
        client = AuthClient(baseURLString: "https://example.com")
        client.sessionManager = Session.default
    }

    func testInit_setsBaseURL() {
        XCTAssertEqual(client.baseURLString, "https://example.com")
    }

    func testFlags_propagateToRetrier() {
        client.isReloadingCancelled = true
        XCTAssertTrue(client.requestRetrier.isReloadingCancelled)

        client.shouldRetryRateLimit = false
        XCTAssertTrue(client.requestRetrier.shouldRetryRateLimit)

        client.shouldAlwaysShowLoginAgain = true
        XCTAssertTrue(client.requestRetrier.shouldAlwaysShowLoginAgain)
    }
}

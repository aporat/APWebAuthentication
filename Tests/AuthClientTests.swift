import XCTest
import Alamofire
@testable import APWebAuthentication

@MainActor
final class AuthClientTests: XCTestCase {

    var client: OAuth2Client!
    var auth: Auth2Authentication!

    override func setUp() {
        super.setUp()
        auth = Auth2Authentication()
        client = OAuth2Client(
            accountType: AccountStore.github,
            baseURLString: "https://example.com",
            requestInterceptor: OAuth2Interceptor(auth: auth)
        )
    }

    func testInit_setsBaseURL() {
        XCTAssertEqual(client.baseURLString, "https://example.com")
    }

    func testSessionManagerUsesEphemeralConfig() {
        let sessionConfig = client.sessionManager.session.configuration
        XCTAssertEqual(sessionConfig.httpShouldSetCookies, false)
    }
}

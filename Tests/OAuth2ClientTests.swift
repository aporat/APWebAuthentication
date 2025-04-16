import XCTest
@testable import APWebAuthentication

final class OAuth2ClientTests: XCTestCase {

    var auth: Auth2Authentication!
    var client: OAuth2Client!

    override func setUp() {
        super.setUp()
        auth = Auth2Authentication()
        client = OAuth2Client(baseURLString: "https://api.example.com", auth: auth)
    }

    func testInitialization_setsBaseURLAndSessionManager() {
        XCTAssertEqual(client.baseURLString, "https://api.example.com")
        XCTAssertNotNil(client.sessionManager)
    }

    func testSessionManagerUsesEphemeralConfig() {
        let sessionConfig = client.sessionManager.session.configuration
        XCTAssertEqual(sessionConfig.httpShouldSetCookies, false)
        XCTAssertEqual(sessionConfig.identifier, nil) // ephemeral has no identifier
    }
}

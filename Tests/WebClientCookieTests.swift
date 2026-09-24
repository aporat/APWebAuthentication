@testable import APWebAuthentication
import XCTest

@MainActor
final class WebClientCookieTests: XCTestCase {

    func testPinterestWebClient_sendsCookiesFromAuthJar() {
        let auth = PinterestWebAuthentication()
        let client = PinterestWebAPIClient(auth: auth)

        let configuration = client.sessionManager.session.configuration

        XCTAssertTrue(configuration.httpShouldSetCookies)
        XCTAssertTrue(configuration.httpCookieStorage === auth.cookieStorage)
    }
}

@testable import APWebAuthentication
import XCTest

@MainActor
final class WebClientCookieTests: XCTestCase {

    func testTikTokWebClient_sendsCookiesFromAuthJar() {
        let auth = TikTokWebAuthentication()
        let client = TikTokWebAPIClient(auth: auth)

        let configuration = client.sessionManager.session.configuration

        XCTAssertTrue(configuration.httpShouldSetCookies)
        XCTAssertTrue(configuration.httpCookieStorage === auth.cookieStorage)
    }

    func testTikTokWebMobileClient_sendsCookiesFromAuthJar() {
        let auth = TikTokWebAuthentication()
        let client = TikTokWebMobileAPIClient(auth: auth)

        let configuration = client.sessionManager.session.configuration

        XCTAssertTrue(configuration.httpShouldSetCookies)
        XCTAssertTrue(configuration.httpCookieStorage === auth.cookieStorage)
    }

    func testPinterestWebClient_sendsCookiesFromAuthJar() {
        let auth = PinterestWebAuthentication()
        let client = PinterestWebAPIClient(auth: auth)

        let configuration = client.sessionManager.session.configuration

        XCTAssertTrue(configuration.httpShouldSetCookies)
        XCTAssertTrue(configuration.httpCookieStorage === auth.cookieStorage)
    }
}

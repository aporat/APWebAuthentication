import APUserAgentGenerator
@testable import APWebAuthentication
import XCTest

@MainActor
final class AuthenticationTests: XCTestCase {

    class TestAuth: Authentication {}

    var auth: Authentication!

    override func setUp() async throws {
        auth = TestAuth()
    }

    func testUserAgent_customUserAgentOverrides() {
        auth.customUserAgent = "CustomAgent"
        XCTAssertEqual(auth.userAgent, "CustomAgent")
    }

    func testUserAgent_returnsDefaultiOS() {
        auth.browserMode = .ios
        auth.customUserAgent = nil
        XCTAssertEqual(auth.userAgent, BrowserUserAgent.default.value)
        XCTAssertTrue(auth.userAgent?.hasPrefix("Mozilla/5.0 (iPhone; CPU iPhone OS ") ?? false)
    }

    func testUserAgent_nilModeMatchesDefault() {
        auth.browserMode = nil
        XCTAssertEqual(auth.userAgent, BrowserUserAgent.default.value)
    }

    func testUserAgent_returnsCriOSForIOSChrome() throws {
        auth.browserMode = .iosChrome
        let expected = try BrowserUserAgent(device: IOSDevice(), browser: ChromeBrowser()).value
        XCTAssertEqual(auth.userAgent, expected)
        XCTAssertTrue(expected.contains(" CriOS/"))
    }

    func testUserAgent_returnsReducedChromeForAndroid() throws {
        auth.browserMode = .android
        let expected = try BrowserUserAgent(device: AndroidDevice(), browser: ChromeBrowser()).value
        XCTAssertEqual(auth.userAgent, expected)
        XCTAssertTrue(expected.hasPrefix("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/"))
        XCTAssertTrue(expected.hasSuffix(".0.0.0 Mobile Safari/537.36"))
    }

    func testUserAgent_returnsChromeForDesktop() {
        auth.browserMode = .desktop
        let userAgent = auth.userAgent ?? ""
        XCTAssertTrue(userAgent.hasPrefix("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/"))
    }

    func testUserAgent_returnsFirefoxForDesktopFirefox() {
        auth.browserMode = .desktopFirefox
        let userAgent = auth.userAgent ?? ""
        XCTAssertTrue(userAgent.hasPrefix("Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:"))
        XCTAssertTrue(userAgent.contains(" Gecko/20100101 Firefox/"))
    }

    func testWebAuthViewController_browserUserAgentReportsTheRunningIOSVersion() throws {
        let userAgent = WebAuthViewController.browserUserAgent
        let expected = try BrowserUserAgent(device: IOSDevice.current, browser: SafariBrowser()).value
        XCTAssertEqual(userAgent, expected)
        XCTAssertTrue(userAgent.hasSuffix(" Mobile/15E148 Safari/604.1"))
    }

    func testUserAgent_webView_returnsNil() {
        auth.browserMode = .webView
        XCTAssertNil(auth.userAgent)
    }

    func testLocaleIdentifiers() {
        XCTAssertTrue(auth.localeIdentifier.contains("_"))
        XCTAssertEqual(auth.localeWebIdentifier, auth.localeIdentifier.replacingOccurrences(of: "_", with: "-"))
        XCTAssertEqual(auth.localeRegionIdentifier.count, 2)
        XCTAssertEqual(auth.localeLanguageCode.count, 2)
    }

    func testDelete_doesNotCrashIfIdentifierMissing() async {
        auth.accountIdentifier = nil
        await auth.delete()
        // no crash = pass
    }
}

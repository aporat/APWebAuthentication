@testable import APWebAuthentication
import XCTest

@MainActor
final class AuthenticationTests: XCTestCase {

    class TestAuth: Authentication {}

    var auth: Authentication!

    override func setUp() {
        super.setUp()
        auth = TestAuth()
    }

    func testAuthSettingsURL_whenAccountIdentifierIsNil_returnsNil() {
        auth.accountIdentifier = nil
        XCTAssertNil(auth.authSettingsURL)
    }

    func testAuthSettingsURL_whenAccountIdentifierSet_returnsURL() {
        auth.accountIdentifier = "test_account"
        XCTAssertTrue(auth.authSettingsURL?.path.contains("test_account.settings") ?? false)
    }

    func testUserAgent_customUserAgentOverrides() {
        auth.customUserAgent = "CustomAgent"
        XCTAssertEqual(auth.userAgent, "CustomAgent")
    }

    func testUserAgent_returnsDefaultiOS() {
        auth.browserMode = .ios
        auth.customUserAgent = nil
        XCTAssertNotNil(auth.userAgent)
    }

    func testUserAgent_returnsChromeForAndroid() {
        auth.browserMode = .android
        XCTAssertTrue(auth.userAgent?.contains("Chrome") ?? false)
    }

    func testUserAgent_returnsFirefoxForDesktopFirefox() {
        auth.browserMode = .desktopFirefox
        XCTAssertTrue(auth.userAgent?.contains("Firefox") ?? false)
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

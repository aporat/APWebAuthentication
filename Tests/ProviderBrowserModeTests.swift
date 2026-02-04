@testable import APWebAuthentication
import XCTest

final class UserAgentModeTests: XCTestCase {

    func testInitWithValidRawValue() {
        XCTAssertEqual(UserAgentMode("webview"), .webView)
        XCTAssertEqual(UserAgentMode("ios-chrome"), .iosChrome)
        XCTAssertEqual(UserAgentMode("desktop-firefox"), .desktopFirefox)
    }

    func testInitWithInvalidRawValue() {
        XCTAssertNil(UserAgentMode("not-a-real-mode"))
        XCTAssertNil(UserAgentMode(nil))
    }

    func testRawValues() {
        XCTAssertEqual(UserAgentMode.webView.rawValue, "webview")
        XCTAssertEqual(UserAgentMode.iosChrome.rawValue, "ios-chrome")
        XCTAssertEqual(UserAgentMode.default.rawValue, "default")
    }
}

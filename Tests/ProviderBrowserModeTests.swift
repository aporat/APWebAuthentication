import XCTest
@testable import APWebAuthentication

final class ProviderBrowserModeTests: XCTestCase {

    func testInitWithValidRawValue() {
        XCTAssertEqual(ProviderBrowserMode("webview"), .webView)
        XCTAssertEqual(ProviderBrowserMode("ios-chrome"), .iosChrome)
        XCTAssertEqual(ProviderBrowserMode("desktop-firefox"), .desktopFirefox)
    }

    func testInitWithInvalidRawValue() {
        XCTAssertNil(ProviderBrowserMode("not-a-real-mode"))
        XCTAssertNil(ProviderBrowserMode(nil))
    }

    func testRawValues() {
        XCTAssertEqual(ProviderBrowserMode.webView.rawValue, "webview")
        XCTAssertEqual(ProviderBrowserMode.iosChrome.rawValue, "ios-chrome")
        XCTAssertEqual(ProviderBrowserMode.default.rawValue, "default")
    }
}

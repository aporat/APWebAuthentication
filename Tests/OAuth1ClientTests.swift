import XCTest
import SwiftyJSON
@testable import APWebAuthentication

final class OAuth1ClientTests: XCTestCase {

    var auth: Auth1Authentication!
    var client: OAuth1Client!

    override func setUp() {
        super.setUp()
        auth = Auth1Authentication()
        client = OAuth1Client(
            baseURLString: "https://api.example.com",
            consumerKey: "key123",
            consumerSecret: "secret456",
            auth: auth
        )
    }

    func testLoadSettings_setsBrowserModeAndUserAgent() {
        let json: JSON = [
            "browser_mode": "ios-chrome",
            "custom_user_agent": "MyCustomAgent/1.0"
        ]

        client.loadSettings(json)

        XCTAssertEqual(auth.browserMode, .iosChrome)
        XCTAssertEqual(auth.customUserAgent, "MyCustomAgent/1.0")
    }

    func testLoadSettings_withInvalidValues_doesNotCrash() {
        let json: JSON = [
            "browser_mode": "invalid_mode",
            "custom_user_agent": JSON.null
        ]

        client.loadSettings(json)

        XCTAssertNil(auth.browserMode)
        XCTAssertNil(auth.customUserAgent)
    }
}

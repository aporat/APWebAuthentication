@testable import APWebAuthentication
import XCTest

/// `cookieStorage` used to be a `lazy var`, so it captured whichever
/// `sessionIdentifier` happened to be current at first access. Restoring a
/// saved account assigns the identifier after init — if anything had touched
/// the storage first, the restored session kept reading a freshly generated,
/// empty jar.
@MainActor
final class SessionAuthenticationCookieStorageTests: XCTestCase {

    func testChangingSessionIdentifier_swapsCookieStorage() {
        let auth = SessionAuthentication()
        let original = auth.cookieStorage

        auth.sessionIdentifier = "session-restored-account"

        XCTAssertFalse(auth.cookieStorage === original)
    }

    func testCookieStorage_isStableForTheSameIdentifier() {
        let auth = SessionAuthentication()

        XCTAssertTrue(auth.cookieStorage === auth.cookieStorage)
    }

    func testReassigningTheSameIdentifier_keepsTheStorage() {
        let auth = SessionAuthentication()
        let storage = auth.cookieStorage
        let identifier = auth.sessionIdentifier

        auth.sessionIdentifier = identifier

        XCTAssertTrue(auth.cookieStorage === storage)
    }

    func testCookiesSetBeforeTheSwap_doNotLeakIntoTheNewJar() {
        let auth = SessionAuthentication()
        auth.sessionIdentifier = "session-first"
        let cookie = HTTPCookie(properties: [
            .name: "sessionid",
            .value: "first",
            .domain: "example.com",
            .path: "/"
        ])!
        auth.setCookies([cookie])
        XCTAssertEqual(auth.getCookies()?.count, 1)

        auth.sessionIdentifier = "session-second"

        XCTAssertEqual(auth.getCookies()?.count ?? 0, 0)
    }

    func testAcceptPolicy_isAppliedToARebuiltStorage() {
        let auth = SessionAuthentication()
        auth.sessionIdentifier = "session-policy-check"

        XCTAssertEqual(auth.cookieStorage.cookieAcceptPolicy, .always)
    }
}

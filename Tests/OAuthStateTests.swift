@testable import APWebAuthentication
import XCTest

/// CSRF protection for OAuth callbacks (RFC 6749 §10.12). The check lives in
/// `URL.getResponse(expectedState:)` so both entry points — the in-app web view
/// via `WebAuthRedirectHandler`, and a raw `ASWebAuthenticationSession`
/// callback the caller parses itself — share one implementation.
final class OAuthStateTests: XCTestCase {

    private let redirect = URL(string: "https://example.com/callback")!

    // MARK: - URL.getResponse(expectedState:)

    func testMatchingState_succeeds() {
        let url = URL(string: "https://example.com/callback?code=abc&state=xyz")!

        guard case .success(let params) = url.getResponse(expectedState: "xyz") else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(params["code"], "abc")
    }

    func testMismatchedState_fails() {
        let url = URL(string: "https://example.com/callback?code=abc&state=attacker")!

        guard case .failure = url.getResponse(expectedState: "xyz") else {
            return XCTFail("expected a state mismatch failure")
        }
    }

    func testMissingState_failsWhenOneWasExpected() {
        let url = URL(string: "https://example.com/callback?code=abc")!

        guard case .failure = url.getResponse(expectedState: "xyz") else {
            return XCTFail("expected a state mismatch failure")
        }
    }

    func testNilExpectedState_skipsTheCheck() {
        let url = URL(string: "https://example.com/callback?code=abc")!

        guard case .success = url.getResponse(expectedState: nil) else {
            return XCTFail("expected success")
        }
    }

    /// An attacker can forge `error=` just as easily as `code=`, so a callback
    /// that fails the state check must be rejected as a mismatch rather than
    /// surfacing the attacker's error message to the user.
    func testErrorCallbackWithWrongState_reportsMismatchNotProviderError() {
        let url = URL(string: "https://example.com/callback?error=access_denied&state=attacker")!

        guard case .failure(let error) = url.getResponse(expectedState: "xyz"),
              case .failed(let reason, _) = error else {
            return XCTFail("expected a failure")
        }
        XCTAssertEqual(reason, "OAuth state mismatch — possible CSRF.")
    }

    /// Implicit-grant providers return the callback in the fragment, which
    /// `URL.parameters` decodes alongside the query.
    func testStateInFragment_isVerified() {
        let url = URL(string: "https://example.com/callback#access_token=t&state=xyz")!

        guard case .success = url.getResponse(expectedState: "xyz") else {
            return XCTFail("expected success")
        }
        guard case .failure = url.getResponse(expectedState: "other") else {
            return XCTFail("expected a state mismatch failure")
        }
    }

    // MARK: - WebAuthRedirectHandler

    @MainActor
    func testRedirectHandler_rejectsMismatchedState() {
        let handler = WebAuthRedirectHandler(redirectURL: redirect, expectedState: "xyz")
        let url = URL(string: "https://example.com/callback?code=abc&state=attacker")!

        guard case .failure? = handler.checkRedirect(url: url) else {
            return XCTFail("expected a state mismatch failure")
        }
    }

    @MainActor
    func testRedirectHandler_acceptsMatchingState() {
        let handler = WebAuthRedirectHandler(redirectURL: redirect, expectedState: "xyz")
        let url = URL(string: "https://example.com/callback?code=abc&state=xyz")!

        guard case .success? = handler.checkRedirect(url: url) else {
            return XCTFail("expected success")
        }
    }

    @MainActor
    func testRedirectHandler_ignoresNonMatchingURLs() {
        let handler = WebAuthRedirectHandler(redirectURL: redirect, expectedState: "xyz")
        let url = URL(string: "https://elsewhere.com/callback?code=abc")!

        XCTAssertNil(handler.checkRedirect(url: url))
    }

    // MARK: - generateState

    func testGeneratedState_isUrlSafeAndUnique() {
        let first = WebAuthRedirectHandler.generateState()
        let second = WebAuthRedirectHandler.generateState()

        XCTAssertNotEqual(first, second)
        XCTAssertFalse(first.isEmpty)
        XCTAssertFalse(first.contains("+"))
        XCTAssertFalse(first.contains("/"))
        XCTAssertFalse(first.contains("="))
    }

    /// A generated state must survive a round trip through the callback URL's
    /// percent-decoding unchanged, or every flow would fail the check.
    func testGeneratedState_roundTripsThroughACallbackURL() {
        let state = WebAuthRedirectHandler.generateState()
        var components = URLComponents(url: redirect, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "code", value: "abc"),
            URLQueryItem(name: "state", value: state)
        ]

        guard case .success = components.url!.getResponse(expectedState: state) else {
            return XCTFail("expected success")
        }
    }
}

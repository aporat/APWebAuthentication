@testable import APWebAuthentication
import XCTest

final class URLResponseParsingTests: XCTestCase {

    private func failureReason(_ urlString: String) -> String? {
        guard case .failure(let error) = URL(string: urlString)!.getResponse() else { return nil }
        if case .failed(let reason, _) = error { return reason }
        if case .sessionExpired(let reason, _) = error { return reason }
        return nil
    }

    func testErrorDescription_isDecodedExactlyOnce() {
        // `%25` must come out as a single literal `%`, `%2B` as a literal `+`.
        let reason = failureReason("myapp://callback?error=access_denied&error_description=Quota%3A%2050%25%20used%2C%20C%2B%2B")

        XCTAssertEqual(reason, "Quota: 50% used, C++")
    }

    func testErrorDescription_plusIsStillTreatedAsSpace() {
        let reason = failureReason("myapp://callback?error=access_denied&error_description=User+cancelled+login")

        XCTAssertEqual(reason, "User cancelled login")
    }

    func testLoginFailed_mapsToSessionExpired() {
        let result = URL(string: "myapp://callback?error_type=login_failed&error_message=Bad%20password")!.getResponse()

        guard case .failure(.sessionExpired(let reason, _)) = result else {
            return XCTFail("expected sessionExpired, got \(result)")
        }
        XCTAssertEqual(reason, "Bad password")
    }

    func testSuccess_returnsAllParameters() {
        let result = URL(string: "myapp://callback?code=abc&state=xyz")!.getResponse()

        guard case .success(let params) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(params, ["code": "abc", "state": "xyz"])
    }
}

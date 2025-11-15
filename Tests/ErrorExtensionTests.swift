import XCTest
import Alamofire
@testable import APWebAuthentication

final class ErrorExtensionTests: XCTestCase {

    func makeURLError(_ code: URLError.Code) -> URLError {
        return URLError(code)
    }

    func testConnectionErrors_areRecognized() {
        let codes: [URLError.Code] = [
            .timedOut, .dnsLookupFailed, .secureConnectionFailed,
            .notConnectedToInternet, .cannotFindHost, .networkConnectionLost
        ]

        for code in codes {
            let error = makeURLError(code)
            XCTAssertTrue(error.isConnectionError, "\(code) should be connection error")
        }

        let nonConnectionError = makeURLError(.cancelled)
        XCTAssertFalse(nonConnectionError.isConnectionError)
    }

    func testAFErrorWrappedConnectionError() {
        let urlError = URLError(.notConnectedToInternet)
        let afError = AFError.sessionTaskFailed(error: urlError)
        XCTAssertTrue(afError.isConnectionError)
    }

    func testCancelledErrors_areRecognized() {
        let canceledURLError = URLError(.cancelled)
        XCTAssertTrue(canceledURLError.isCancelledError)

        let afCancel = AFError.explicitlyCancelled
        XCTAssertTrue(afCancel.isCancelledError)

        let wrapped = AFError.sessionTaskFailed(error: authError)
        XCTAssertTrue(wrapped.isCancelledError)
    }

    func testIgnorableErrors() {
        XCTAssertTrue(URLError(.timedOut).isIgnorableError)
        XCTAssertTrue(APWebAuthenticationError.badRequest.isIgnorableError)
    }

    func testNonIgnorableError() {
        let error = NSError(domain: "Test", code: 42)
        XCTAssertFalse(error.isConnectionError)
        XCTAssertFalse(error.isCancelledError)
        XCTAssertFalse(error.isIgnorableError)
    }
}

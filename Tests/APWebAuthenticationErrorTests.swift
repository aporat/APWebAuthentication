@testable import APWebAuthentication
import SwiftyJSON
import XCTest

final class APWebAuthenticationErrorTests: XCTestCase {

    // MARK: - Test Error Titles

    func testErrorTitle() {
        // Each error case maps to a distinct user-facing title
        XCTAssertEqual(APWebAuthenticationError.checkPointRequired(reason: nil, responseJSON: nil).errorTitle, "Security Check")
        XCTAssertEqual(APWebAuthenticationError.connectionError(reason: nil).errorTitle, "Network Error")
        XCTAssertEqual(APWebAuthenticationError.serverError(reason: nil).errorTitle, "Server Error")
        XCTAssertEqual(APWebAuthenticationError.sessionExpired(reason: nil).errorTitle, "Session Expired")
        XCTAssertEqual(APWebAuthenticationError.rateLimit(reason: nil).errorTitle, "Rate Limit Reached")
        XCTAssertEqual(APWebAuthenticationError.feedbackRequired(reason: nil).errorTitle, "Action Blocked")
        XCTAssertEqual(APWebAuthenticationError.externalActionRequired(reason: nil).errorTitle, "Action Blocked")
        XCTAssertEqual(APWebAuthenticationError.canceled.errorTitle, "Error")
        XCTAssertEqual(APWebAuthenticationError.timeout.errorTitle, "Error")
    }

    // MARK: - Test Error Descriptions

    func testErrorDescriptionWithReason() {
        let loginError = APWebAuthenticationError.sessionExpired(reason: "Invalid credentials")
        XCTAssertEqual(loginError.errorDescription, "Invalid credentials")

        let connectionError = APWebAuthenticationError.connectionError(reason: "No internet")
        XCTAssertEqual(connectionError.errorDescription, "No internet")

        let serverError = APWebAuthenticationError.serverError(reason: "Internal error")
        XCTAssertEqual(serverError.errorDescription, "Internal error")

        let rateLimitError = APWebAuthenticationError.rateLimit(reason: "Too many requests")
        XCTAssertEqual(rateLimitError.errorDescription, "Too many requests")
    }

    // MARK: - Test Error Codes

    func testErrorCode() {
        // Each error case has a unique, stable machine-readable code
        XCTAssertEqual(APWebAuthenticationError.failed(reason: nil).errorCode, "failed")
        XCTAssertEqual(APWebAuthenticationError.connectionError(reason: nil).errorCode, "connection_error")
        XCTAssertEqual(APWebAuthenticationError.serverError(reason: nil).errorCode, "server_error")
        XCTAssertEqual(APWebAuthenticationError.rateLimit(reason: nil).errorCode, "rate_limit")
        XCTAssertEqual(APWebAuthenticationError.sessionExpired(reason: nil).errorCode, "session_expired")
        XCTAssertEqual(APWebAuthenticationError.checkPointRequired(reason: nil, responseJSON: nil).errorCode, "checkpoint_required")
        XCTAssertEqual(APWebAuthenticationError.canceled.errorCode, "canceled")
        XCTAssertEqual(APWebAuthenticationError.timeout.errorCode, "timeout")
        XCTAssertEqual(APWebAuthenticationError.badRequest.errorCode, "bad_request")
        XCTAssertEqual(APWebAuthenticationError.unknown.errorCode, "bad_request")
    }

    // MARK: - Test Response JSON Extraction

    func testResponseJSONExtraction() {
        let json = JSON(["key": "value"])
        let checkpointError = APWebAuthenticationError.checkPointRequired(reason: nil, responseJSON: json)
        XCTAssertEqual(checkpointError.responseJSON, json)

        let twoFactorError = APWebAuthenticationError.twoFactorRequired(responseJSON: json)
        XCTAssertEqual(twoFactorError.responseJSON, json)

        let loginError = APWebAuthenticationError.sessionExpired(reason: nil)
        XCTAssertNil(loginError.responseJSON)

        let noJSONCheckpoint = APWebAuthenticationError.checkPointRequired(reason: nil, responseJSON: nil)
        XCTAssertNil(noJSONCheckpoint.responseJSON)
    }

    // MARK: - Test Error Categories

    func testIsLoginError() {
        // All login-related errors should return true
        XCTAssertTrue(APWebAuthenticationError.sessionExpired(reason: nil).isLoginError)
        XCTAssertTrue(APWebAuthenticationError.checkPointRequired(reason: nil, responseJSON: nil).isLoginError)
        XCTAssertTrue(APWebAuthenticationError.feedbackRequired(reason: nil).isLoginError)
        // Non-login errors should return false
        XCTAssertFalse(APWebAuthenticationError.connectionError(reason: nil).isLoginError)
        XCTAssertFalse(APWebAuthenticationError.timeout.isLoginError)
    }
}

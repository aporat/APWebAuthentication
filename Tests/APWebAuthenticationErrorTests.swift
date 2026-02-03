import XCTest
@testable import APWebAuthentication
import SwiftyJSON

final class APWebAuthenticationErrorTests: XCTestCase {
    
    // MARK: - Test Error Titles
    
    func testErrorTitle() {
        XCTAssertEqual(APWebAuthenticationError.loginFailed(reason: nil).errorTitle, "Login Failed")
        XCTAssertEqual(APWebAuthenticationError.connectionError(reason: nil).errorTitle, "Network Error")
        XCTAssertEqual(APWebAuthenticationError.serverError(reason: nil).errorTitle, "Server Error")
        XCTAssertEqual(APWebAuthenticationError.sessionExpired(reason: nil).errorTitle, "Session Expired")
        XCTAssertEqual(APWebAuthenticationError.appSessionExpired(reason: nil).errorTitle, "Session Expired")
        XCTAssertEqual(APWebAuthenticationError.rateLimit(reason: nil).errorTitle, "Rate Limit Reached")
        XCTAssertEqual(APWebAuthenticationError.feedbackRequired(reason: nil).errorTitle, "Action Blocked")
        XCTAssertEqual(APWebAuthenticationError.externalActionRequired(reason: nil).errorTitle, "Action Blocked")
        XCTAssertEqual(APWebAuthenticationError.canceled.errorTitle, "Error")
        XCTAssertEqual(APWebAuthenticationError.timeout.errorTitle, "Error")
    }
    
    // MARK: - Test Error Descriptions
    
    func testErrorDescriptionWithReason() {
        let loginError = APWebAuthenticationError.loginFailed(reason: "Invalid credentials")
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
        XCTAssertEqual(APWebAuthenticationError.loginFailed(reason: nil).errorCode, "login_failed")
        XCTAssertEqual(APWebAuthenticationError.connectionError(reason: nil).errorCode, "connection_error")
        XCTAssertEqual(APWebAuthenticationError.serverError(reason: nil).errorCode, "server_error")
        XCTAssertEqual(APWebAuthenticationError.rateLimit(reason: nil).errorCode, "rate_limit")
        XCTAssertEqual(APWebAuthenticationError.appSessionExpired(reason: nil).errorCode, "app_session_expired")
        XCTAssertEqual(APWebAuthenticationError.checkPointRequired(content: nil).errorCode, "checkpoint_required")
        XCTAssertEqual(APWebAuthenticationError.canceled.errorCode, "canceled")
        XCTAssertEqual(APWebAuthenticationError.timeout.errorCode, "timeout")
        XCTAssertEqual(APWebAuthenticationError.badRequest.errorCode, "bad_request")
        XCTAssertEqual(APWebAuthenticationError.unknown.errorCode, "bad_request")
    }
    
    // MARK: - Test Content Extraction
    
    func testContentExtraction() {
        let json = JSON(["key": "value"])
        let checkpointError = APWebAuthenticationError.appCheckPointRequired(content: json)
        XCTAssertEqual(checkpointError.content, json)
        
        let downloadError = APWebAuthenticationError.appDownloadNewAppRequired(content: json)
        XCTAssertEqual(downloadError.content, json)
        
        let updateError = APWebAuthenticationError.appUpdateRequired(content: json)
        XCTAssertEqual(updateError.content, json)
        
        let loginError = APWebAuthenticationError.loginFailed(reason: nil)
        XCTAssertNil(loginError.content)
        
        let noContentCheckpoint = APWebAuthenticationError.appCheckPointRequired(content: nil)
        XCTAssertNil(noContentCheckpoint.content)
    }
    
    // MARK: - Test Error Categories
    func testIsLoginError() {
        XCTAssertTrue(APWebAuthenticationError.loginFailed(reason: nil).isLoginError)
        XCTAssertTrue(APWebAuthenticationError.sessionExpired(reason: nil).isLoginError)
        XCTAssertTrue(APWebAuthenticationError.appSessionExpired(reason: nil).isLoginError)
        XCTAssertTrue(APWebAuthenticationError.feedbackRequired(reason: nil).isLoginError)
        XCTAssertFalse(APWebAuthenticationError.connectionError(reason: nil).isLoginError)
        XCTAssertFalse(APWebAuthenticationError.timeout.isLoginError)
    }
}

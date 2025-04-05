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
    
    func testErrorDescriptionWithoutReason() {
        let loginError = APWebAuthenticationError.loginFailed(reason: nil)
        XCTAssertEqual(loginError.errorDescription, "Unable to login. Server could also be down.")
        
        let connectionError = APWebAuthenticationError.connectionError(reason: nil)
        XCTAssertEqual(connectionError.errorDescription, "Check your network connection. Server could also be down.")
        
        let sessionError = APWebAuthenticationError.sessionExpired(reason: nil)
        XCTAssertEqual(sessionError.errorDescription, "Your session has expired. Please login again.")
        
        let timeoutError = APWebAuthenticationError.timeout
        XCTAssertEqual(timeoutError.errorDescription, "Unable to perform action. Please try again later.")
        
        let canceledError = APWebAuthenticationError.canceled
        XCTAssertEqual(canceledError.errorDescription, "Unable to perform action. Please try again later.")
    }
    
    func testErrorDescriptionWithEmptyReason() {
        let loginError = APWebAuthenticationError.loginFailed(reason: "")
        XCTAssertEqual(loginError.errorDescription, "Unable to login. Server could also be down.")
        
        let feedbackError = APWebAuthenticationError.feedbackRequired(reason: "")
        XCTAssertNil(feedbackError.errorDescription)
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
    
    func testIsAppError() {
        XCTAssertTrue(APWebAuthenticationError.appSessionExpired(reason: nil).isAppError)
        XCTAssertTrue(APWebAuthenticationError.appCheckPointRequired(content: nil).isAppError)
        XCTAssertTrue(APWebAuthenticationError.appDownloadNewAppRequired(content: nil).isAppError)
        XCTAssertTrue(APWebAuthenticationError.appUpdateRequired(content: nil).isAppError)
        XCTAssertFalse(APWebAuthenticationError.loginFailed(reason: nil).isAppError)
        XCTAssertFalse(APWebAuthenticationError.canceled.isAppError)
    }
    
    func testIsLoginError() {
        XCTAssertTrue(APWebAuthenticationError.loginFailed(reason: nil).isLoginError)
        XCTAssertTrue(APWebAuthenticationError.sessionExpired(reason: nil).isLoginError)
        XCTAssertTrue(APWebAuthenticationError.appSessionExpired(reason: nil).isLoginError)
        XCTAssertTrue(APWebAuthenticationError.feedbackRequired(reason: nil).isLoginError)
        XCTAssertFalse(APWebAuthenticationError.connectionError(reason: nil).isLoginError)
        XCTAssertFalse(APWebAuthenticationError.timeout.isLoginError)
    }
    
    func testIsGenericError() {
        XCTAssertTrue(APWebAuthenticationError.failed(reason: nil).isGenericError)
        XCTAssertTrue(APWebAuthenticationError.serverError(reason: nil).isGenericError)
        XCTAssertTrue(APWebAuthenticationError.notFound.isGenericError)
        XCTAssertTrue(APWebAuthenticationError.badRequest.isGenericError)
        XCTAssertFalse(APWebAuthenticationError.loginFailed(reason: nil).isGenericError)
        XCTAssertFalse(APWebAuthenticationError.appUpdateRequired(content: nil).isGenericError)
    }
}

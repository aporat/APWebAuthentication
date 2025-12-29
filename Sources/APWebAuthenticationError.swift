import Foundation
@preconcurrency import SwiftyJSON

public enum APWebAuthenticationError: Error, Sendable, Equatable {
    
    // MARK: - Cases
    
    case failed(reason: String?, responseJSON: JSON? = nil)
    case connectionError(reason: String?, responseJSON: JSON? = nil)
    case serverError(reason: String?, responseJSON: JSON? = nil)
    case loginFailed(reason: String?, responseJSON: JSON? = nil)
    case feedbackRequired(reason: String?, responseJSON: JSON? = nil)
    case externalActionRequired(reason: String?, responseJSON: JSON? = nil)
    case sessionExpired(reason: String?, responseJSON: JSON? = nil)
    case rateLimit(reason: String?, responseJSON: JSON? = nil)
    case appSessionExpired(reason: String?, responseJSON: JSON? = nil)
    
    case checkPointRequired(content: JSON?)
    case appCheckPointRequired(content: JSON?)
    case appDownloadNewAppRequired(content: JSON?)
    case appUpdateRequired(content: JSON?)
    
    // Unchanged cases
    case canceled
    case notFound
    case badRequest
    case unknown
    case timeout
    
    // MARK: - Public JSON Computed Properties
    
    /// The JSON content associated with checkpoint/notice errors.
    public var content: JSON? {
        switch self {
        case let .appCheckPointRequired(content),
            let .checkPointRequired(content),
            let .appDownloadNewAppRequired(content),
            let .appUpdateRequired(content):
            return content
        default:
            return nil
        }
    }
    
    /// The full JSON response associated with the error.
    public var responseJSON: JSON? {
        switch self {
        case let .failed(_, responseJSON),
            let .connectionError(_, responseJSON),
            let .serverError(_, responseJSON),
            let .loginFailed(_, responseJSON),
            let .feedbackRequired(_, responseJSON),
            let .externalActionRequired(_, responseJSON),
            let .sessionExpired(_, responseJSON),
            let .rateLimit(_, responseJSON),
            let .appSessionExpired(_, responseJSON):
            return responseJSON
        default:
            return nil
        }
    }
}

// MARK: - LocalizedError
extension APWebAuthenticationError: LocalizedError {
    
    public var errorTitle: String {
        switch self {
        case .loginFailed:
            return "Login Failed"
        case .connectionError:
            return "Network Error"
        case .serverError:
            return "Server Error"
        case .sessionExpired, .appSessionExpired:
            return "Session Expired"
        case .rateLimit:
            return "Rate Limit Reached"
        case .feedbackRequired, .externalActionRequired:
            return "Action Blocked"
        case .checkPointRequired, .appCheckPointRequired:
            return "Security Check"
        case .appUpdateRequired:
            return "Update Required"
        default:
            return "Error"
        }
    }
    
    public var errorDescription: String? {
        switch self {
            
            // MARK: - Session Errors (Critical Fix)
        case let .sessionExpired(reason, _),
            let .appSessionExpired(reason, _):
            return reason ?? "Your session has expired. Please log in again."
            
            // MARK: - Login & Access Errors
        case let .loginFailed(reason, _):
            return reason ?? "Unable to login. Please check your credentials and try again."
            
        case let .checkPointRequired(content),
            let .appCheckPointRequired(content):
            return content?["message"].string ?? "A security checkpoint is required to continue."
            
        case let .feedbackRequired(reason, _),
            let .externalActionRequired(reason, _):
            return reason ?? "This action cannot be completed at this time. Instagram may restrict certain activities to protect the community."
            
        case let .rateLimit(reason, _):
            return reason ?? "You are doing this too fast. Please try again later."
            
            // MARK: - Network & Server Errors
        case let .connectionError(reason, _):
            return reason ?? "The Internet connection appears to be offline."
            
        case let .serverError(reason, _):
            return reason ?? "The server encountered an error and could not complete your request. Please try again later."
            
        case let .failed(reason, _):
            return reason ?? "An unknown error occurred."
            
            // MARK: - App Updates
        case .appUpdateRequired, .appDownloadNewAppRequired:
            return "This version of the app is no longer supported. Please update to the latest version."
            
            // MARK: - Others
        case .notFound:
            return "The requested resource could not be found."
            
        case .timeout:
            return "The request timed out."
            
        case .badRequest:
            return "The request was invalid."
            
        case .canceled:
            return "The operation was canceled."
            
        case .unknown:
            return "An unexpected error occurred."
        }
    }
    
    public var errorCode: String? {
        switch self {
        case .failed: return "failed"
        case .connectionError: return "connection_error"
        case .serverError: return "server_error"
        case .loginFailed: return "login_failed"
        case .checkPointRequired: return "checkpoint_required"
        case .feedbackRequired: return "feedback_required"
        case .externalActionRequired: return "external_action_required"
        case .sessionExpired: return "session_expired"
        case .rateLimit: return "rate_limit"
        case .appSessionExpired: return "app_session_expired"
        case .appCheckPointRequired: return "app_checkpoint_required"
        case .appDownloadNewAppRequired: return "app_download_new_app_required"
        case .appUpdateRequired: return "app_update_required"
        case .canceled: return "canceled"
        case .notFound: return "not_found"
        case .timeout: return "timeout"
        case .badRequest, .unknown: return "bad_request"
        }
    }
}

// MARK: - Convenience Properties
extension APWebAuthenticationError {
    
    // This extension also remains unchanged.
    
    public var isAppError: Bool {
        switch self {
        case .appSessionExpired, .appCheckPointRequired, .appDownloadNewAppRequired, .appUpdateRequired:
            return true
        default:
            return false
        }
    }
    
    public var isLoginError: Bool {
        switch self {
        case .loginFailed, .sessionExpired, .appSessionExpired, .feedbackRequired, .checkPointRequired:
            return true
        default:
            return false
        }
    }
    
    public var isGenericError: Bool {
        switch self {
        case .failed, .serverError, .notFound, .badRequest:
            return true
        default:
            return false
        }
    }
}

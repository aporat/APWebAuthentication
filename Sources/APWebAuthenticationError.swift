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
    
    case checkPointRequired(responseJSON: JSON?)
    case appCheckPointRequired(responseJSON: JSON?)
    case appTwoFactorRequired(responseJSON: JSON?)
    case appDownloadNewAppRequired(responseJSON: JSON?)
    case appUpdateRequired(responseJSON: JSON?)
    
    case canceled
    case notFound
    case badRequest
    case unknown
    case timeout
    
    // MARK: - Public Computed Property
    
    public var responseJSON: JSON? {
        switch self {
        case let .failed(_, json),
             let .connectionError(_, json),
             let .serverError(_, json),
             let .loginFailed(_, json),
             let .feedbackRequired(_, json),
             let .externalActionRequired(_, json),
             let .sessionExpired(_, json),
             let .rateLimit(_, json),
             let .appSessionExpired(_, json),
             let .checkPointRequired(json),
             let .appCheckPointRequired(json),
             let .appTwoFactorRequired(json),
             let .appDownloadNewAppRequired(json),
             let .appUpdateRequired(json):
            return json
            
        case .canceled, .notFound, .badRequest, .unknown, .timeout:
            return nil
        }
    }
}

// MARK: - LocalizedError
extension APWebAuthenticationError: LocalizedError {
    
    public var errorTitle: String {
        switch self {
        case .loginFailed: return "Login Failed"
        case .connectionError: return "Network Error"
        case .serverError: return "Server Error"
        case .sessionExpired, .appSessionExpired: return "Session Expired"
        case .rateLimit: return "Rate Limit Reached"
        case .feedbackRequired, .externalActionRequired: return "Action Blocked"
        case .checkPointRequired, .appCheckPointRequired: return "Security Check"
        case .appTwoFactorRequired: return "Two-Factor Authentication"
        case .appUpdateRequired: return "Update Required"
        default: return "Error"
        }
    }
    
    public var errorDescription: String? {
        switch self {
            
        // MARK: - Session Errors
        case let .sessionExpired(reason, _),
             let .appSessionExpired(reason, _):
            return reason ?? "Your session has expired. Please log in again."
            
        // MARK: - Login & Access Errors
        case let .loginFailed(reason, _):
            return reason ?? "Unable to login. Please check your credentials and try again."
            
        case let .checkPointRequired(json),
             let .appCheckPointRequired(json):
            return json?["message"].string ?? "A security checkpoint is required to continue."
            
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
        case .notFound: return "The requested resource could not be found."
        case .timeout: return "The request timed out."
        case .badRequest: return "The request was invalid."
        case .canceled: return "The operation was canceled."
        case .unknown: return "An unexpected error occurred."
        case .appTwoFactorRequired: return "Two-factor authentication is required."
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
        case .appTwoFactorRequired: return "app_two_factor_required"
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
    
    public var isAppError: Bool {
        switch self {
        case .appSessionExpired, .appCheckPointRequired, .appTwoFactorRequired, .appDownloadNewAppRequired, .appUpdateRequired:
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

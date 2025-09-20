import Foundation
@preconcurrency import SwiftyJSON

public enum APWebAuthenticationError: Error, Sendable, Equatable {
    case failed(reason: String?)
    case connectionError(reason: String?)
    case serverError(reason: String?)
    case loginFailed(reason: String?)
    case feedbackRequired(reason: String?)
    case checkPointRequired(content: JSON?)
    case checkPointNotice(content: JSON?)
    case externalActionRequired(reason: String?)
    case sessionExpired(reason: String?)
    case rateLimit(reason: String?)
    case canceled
    case loginCanceled
    case notFound
    case badRequest
    case unknown
    case timeout

    // App API Errors
    case appSessionExpired(reason: String?)
    case appCheckPointRequired(content: JSON?)
    case appDownloadNewAppRequired(content: JSON?)
    case appUpdateRequired(content: JSON?)

    public var content: JSON? {
        switch self {
        case let .appCheckPointRequired(content),
             let .checkPointRequired(content),
             let .checkPointNotice(content),
             let .appDownloadNewAppRequired(content),
             let .appUpdateRequired(content):
            return content
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
        default:
            return "Error"
        }
    }

    public var errorDescription: String? {
        switch self {
        case let .failed(reason),
             let .serverError(reason),
             let .feedbackRequired(reason),
             let .externalActionRequired(reason),
             let .sessionExpired(reason),
             let .appSessionExpired(reason):
            return reason
            
        case let .connectionError(reason):
            return reason ?? "Check your network connection. The server could also be down."
            
        case let .loginFailed(reason):
            return reason ?? "Unable to login. The server could also be down."
            
        case let .rateLimit(reason):
            return reason ?? "You have made too many requests. Please try again later."
            
        default:
            return "Unable to perform this action. Please try again later."
        }
    }
    
    public var errorCode: String? {
        switch self {
        case .failed: return "failed"
        case .connectionError: return "connection_error"
        case .serverError: return "server_error"
        case .loginFailed: return "login_failed"
        case .checkPointRequired: return "checkpoint_required"
        case .checkPointNotice: return "checkpoint_notice"
        case .feedbackRequired: return "feedback_required"
        case .externalActionRequired: return "external_action_required"
        case .sessionExpired: return "session_expired"
        case .rateLimit: return "rate_limit"
        case .appSessionExpired: return "app_session_expired"
        case .appCheckPointRequired: return "app_checkpoint_required"
        case .appDownloadNewAppRequired: return "app_download_new_app_required"
        case .appUpdateRequired: return "app_update_required"
        case .canceled: return "canceled"
        case .loginCanceled: return "login_canceled"
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
        case .appSessionExpired, .appCheckPointRequired, .appDownloadNewAppRequired, .appUpdateRequired:
            return true
        default:
            return false
        }
    }

    public var isLoginError: Bool {
        switch self {
        case .loginFailed, .sessionExpired, .appSessionExpired, .feedbackRequired:
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

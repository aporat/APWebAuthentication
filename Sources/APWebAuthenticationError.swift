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
    
    // This extension remains unchanged as it only accesses `String` properties.
    
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
        case let .failed(reason, _),
             let .serverError(reason, _),
             let .feedbackRequired(reason, _),
             let .externalActionRequired(reason, _),
             let .sessionExpired(reason, _),
             let .appSessionExpired(reason, _):
            return reason
            
        case let .connectionError(reason, _):
            return reason ?? "Check your network connection. The server could also be down."
            
        case let .loginFailed(reason, _):
            return reason ?? "Unable to login. The server could also be down."
            
        case let .rateLimit(reason, _):
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

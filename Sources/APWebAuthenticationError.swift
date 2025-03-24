import Foundation
import SwiftyJSON

public enum APWebAuthenticationError: Error {
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
             let .appDownloadNewAppRequired(content),
             let .appUpdateRequired(content):
            return content
        default:
            return nil
        }
    }
}

extension APWebAuthenticationError: LocalizedError {
    public var errorTitle: String {
        switch self {
        case .loginFailed:
            return "Login Failed"
        case .connectionError:
            return "Network Error"
        case .serverError:
            return "Server Error"
        case .sessionExpired(_), .appSessionExpired:
            return "Session Expired"
        case .rateLimit:
            return "Rate Limit Reached"
        case .feedbackRequired(_), .externalActionRequired:
            return "Action Blocked"
        default:
            return "Error"
        }
    }

    public var errorDescription: String? {
        switch self {
        case let .failed(reason), let .serverError(reason), let .feedbackRequired(reason), let .externalActionRequired(reason):

            if let reason = reason, !reason.isEmpty {
                return reason
            }

            return nil
        case let .connectionError(reason):

            if let reason = reason, !reason.isEmpty {
                return reason
            }

            return "Check your network connection. Server could also be down."
        case let .loginFailed(reason):

            if let reason = reason, !reason.isEmpty {
                return reason
            }

            return "Unable to login. Server could also be down."
        case let .rateLimit(reason):

            if let reason = reason, !reason.isEmpty {
                return reason
            }

            return "You have made too many requests. Please try again later"
        case let .sessionExpired(reason), let .appSessionExpired(reason):

            if let reason = reason, !reason.isEmpty {
                return reason
            }

            return "Your session has expired. Please login again."
        default:
            return "Unable to perform action. Please try again later."
        }
    }

    public var errorCode: String? {
        switch self {
        case .failed:
            return "failed"
        case .connectionError:
            return "connection_error"
        case .serverError:
            return "server_error"
        case .loginFailed:
            return "login_failed"
        case .checkPointRequired:
            return "checkpoint_required"
        case .checkPointNotice:
            return "checkpoint_notice"
        case .feedbackRequired:
            return "feedback_required"
        case .externalActionRequired:
            return "external_action_required"
        case .sessionExpired:
            return "session_expired"
        case .rateLimit:
            return "rate_limit"
        case .appSessionExpired:
            return "app_session_expired"
        case .appCheckPointRequired:
            return "app_checkpoint_required"
        case .appDownloadNewAppRequired:
            return "app_download_new_app_required"
        case .appUpdateRequired:
            return "app_update_required"
        case .canceled:
            return "canceled"
        case .loginCanceled:
            return "login_canceled"
        case .notFound:
            return "not_found"
        case .timeout:
            return "timeout"
        case .badRequest, .unknown:
            return "bad_request"
        }
    }
}

extension APWebAuthenticationError {
    public var isAppError: Bool {
        if case APWebAuthenticationError.appSessionExpired = self {
            return true
        }

        if case APWebAuthenticationError.appCheckPointRequired = self {
            return true
        }

        if case APWebAuthenticationError.appDownloadNewAppRequired = self {
            return true
        }

        if case APWebAuthenticationError.appUpdateRequired = self {
            return true
        }

        return false
    }

    public var isLoginError: Bool {
        if case APWebAuthenticationError.loginFailed = self {
            return true
        }

        if case APWebAuthenticationError.sessionExpired = self {
            return true
        }

        if case APWebAuthenticationError.appSessionExpired = self {
            return true
        }

        if case APWebAuthenticationError.feedbackRequired = self {
            return true
        }

        return false
    }

    public var isGenericError: Bool {
        if case APWebAuthenticationError.failed = self {
            return true
        }

        if case APWebAuthenticationError.serverError = self {
            return true
        }

        if case APWebAuthenticationError.notFound = self {
            return true
        }

        if case APWebAuthenticationError.badRequest = self {
            return true
        }

        return false
    }
}

import Foundation
@preconcurrency import SwiftyJSON

/// Errors that can occur during web-based authentication and API requests.
///
/// Covers network errors, authentication failures, rate limiting, security checks,
/// and user-canceled operations.
///
/// **Example Usage:**
/// ```swift
/// do {
///     try await client.login(username: "user", password: "pass")
/// } catch let error as APWebAuthenticationError {
///     switch error {
///     case .checkPointRequired:
///         showSecurityCheckpoint()
///     case .rateLimit:
///         showRateLimitMessage()
///     default:
///         showError(error.errorDescription ?? "Unknown error")
///     }
/// }
/// ```
public enum APWebAuthenticationError: Error, Sendable, Equatable {

    // MARK: - General Errors

    case failed(reason: String?, responseJSON: JSON? = nil)
    case connectionError(reason: String?, responseJSON: JSON? = nil)
    case serverError(reason: String?, responseJSON: JSON? = nil)
    case canceled
    case notFound
    case badRequest
    case unknown
    case timeout

    // MARK: - Authentication Errors

    case feedbackRequired(reason: String?, responseJSON: JSON? = nil)
    case externalActionRequired(reason: String?, responseJSON: JSON? = nil)
    case sessionExpired(reason: String?, responseJSON: JSON? = nil)

    // MARK: - Rate Limiting & Restrictions

    case rateLimit(reason: String?, responseJSON: JSON? = nil)

    // MARK: - Security Checkpoints

    case checkPointRequired(reason: String?, responseJSON: JSON?)
    case twoFactorRequired(responseJSON: JSON?)

    // MARK: - Response JSON Access

    /// The raw JSON response from the server, if available.
    public var responseJSON: JSON? {
        switch self {
        case let .failed(_, json),
             let .connectionError(_, json),
             let .serverError(_, json),
             let .feedbackRequired(_, json),
             let .externalActionRequired(_, json),
             let .sessionExpired(_, json),
             let .rateLimit(_, json),
             let .twoFactorRequired(json),
             let .checkPointRequired(_, json):
            return json

        case .canceled, .notFound, .badRequest, .unknown, .timeout:
            return nil
        }
    }
}

// MARK: - LocalizedError Conformance

extension APWebAuthenticationError: LocalizedError {

    /// User-facing error title for display in alerts and UI.
    public var errorTitle: String {
        switch self {
        case .connectionError:
            return "Network Error"
        case .serverError:
            return "Server Error"
        case .sessionExpired:
            return "Session Expired"
        case .rateLimit:
            return "Rate Limit Reached"
        case .feedbackRequired, .externalActionRequired:
            return "Action Blocked"
        case .checkPointRequired:
            return "Security Check"
        case .twoFactorRequired:
            return "Two-Factor Authentication"
        case .failed, .notFound, .timeout, .badRequest, .canceled, .unknown:
            return "Error"
        }
    }

    /// Detailed user-facing error description for display in alerts and UI.
    public var errorDescription: String? {
        switch self {
        case let .sessionExpired(reason, _):
            return reason ?? "Your session has expired. Please log in again."

        case let .checkPointRequired(reason, _):
            return reason ?? "A security checkpoint is required to continue."

        case let .feedbackRequired(reason, _),
             let .externalActionRequired(reason, _):
            return reason ?? "This action cannot be completed at this time. Instagram may restrict certain activities to protect the community."

        case let .rateLimit(reason, _):
            return reason ?? "You are doing this too fast. Please try again later."

        case let .connectionError(reason, _):
            return reason ?? "The Internet connection appears to be offline."

        case let .serverError(reason, _):
            return reason ?? "The server encountered an error and could not complete your request. Please try again later."

        case let .failed(reason, _):
            return reason ?? "An unknown error occurred."

        case .twoFactorRequired:
            return "Two-factor authentication is required."
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

    /// Machine-readable error code for logging and analytics.
    public var errorCode: String? {
        switch self {
        case .failed:
            return "failed"
        case .connectionError:
            return "connection_error"
        case .serverError:
            return "server_error"
        case .checkPointRequired:
            return "checkpoint_required"
        case .feedbackRequired:
            return "feedback_required"
        case .externalActionRequired:
            return "external_action_required"
        case .sessionExpired:
            return "session_expired"
        case .rateLimit:
            return "rate_limit"
        case .twoFactorRequired:
            return "two_factor_required"
        case .canceled:
            return "canceled"
        case .notFound:
            return "not_found"
        case .timeout:
            return "timeout"
        case .badRequest, .unknown:
            return "bad_request"
        }
    }
}

// MARK: - Error Classification

extension APWebAuthenticationError {

    /// Whether this is a login or authentication-related error.
    public var isLoginError: Bool {
        switch self {
        case .sessionExpired,
             .feedbackRequired,
             .checkPointRequired:
            return true
        default:
            return false
        }
    }

    /// Whether this error is temporary and the operation can be retried.
    public var isRetryable: Bool {
        switch self {
        case .connectionError, .timeout, .rateLimit, .serverError:
            return true
        default:
            return false
        }
    }

    /// Whether this error requires user action to resolve.
    public var requiresUserAction: Bool {
        switch self {
        case .checkPointRequired,
             .twoFactorRequired,
             .feedbackRequired,
             .externalActionRequired:
            return true
        default:
            return false
        }
    }

    /// Whether this error represents a cancelled operation.
    public var isCancelledError: Bool {
        switch self {
        case .canceled:
            return true
        default:
            return false
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension APWebAuthenticationError: CustomDebugStringConvertible {

    /// Detailed debug description for logging and debugging.
    public var debugDescription: String {
        let code = errorCode ?? "unknown"
        var parts = ["APWebAuthenticationError.\(code)"]

        // Add reason if available
        switch self {
        case let .failed(reason, _),
             let .connectionError(reason, _),
             let .serverError(reason, _),
             let .feedbackRequired(reason, _),
             let .externalActionRequired(reason, _),
             let .sessionExpired(reason, _),
             let .rateLimit(reason, _),
             let .checkPointRequired(reason, _):
            if let reason = reason {
                parts.append("reason: \"\(reason)\"")
            }
        default:
            break
        }

        // Indicate if JSON is present
        if responseJSON != nil {
            parts.append("hasJSON: true")
        }

        return parts.count > 1 ? "\(parts[0])(\(parts.dropFirst().joined(separator: ", ")))" : parts[0]
    }
}

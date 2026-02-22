import Foundation
@preconcurrency import SwiftyJSON

/// Errors that can occur during web-based authentication and API requests.
///
/// This error type covers a wide range of failure scenarios:
/// - **Network errors**: Connection issues, timeouts
/// - **Authentication errors**: Login failures, session expiration, security checks
/// - **Server errors**: Rate limiting, server failures, not found
/// - **App-specific errors**: Update required, two-factor authentication
/// - **User errors**: Canceled operations, bad requests
///
/// Many error cases include associated values:
/// - **reason**: A human-readable error message
/// - **responseJSON**: The raw JSON response from the server (useful for debugging)
///
/// **Example Usage:**
/// ```swift
/// do {
///     try await client.login(username: "user", password: "pass")
/// } catch let error as APWebAuthenticationError {
///     switch error {
///     case .checkPointRequired:
///         // Show security checkpoint UI
///         break
///     case .rateLimit:
///         // Show "try again later" message
///         break
///     default:
///         // Show generic error
///         print(error.errorDescription ?? "Unknown error")
///     }
/// }
/// ```
///
/// - Note: All cases are `Sendable` and can be safely passed across concurrency boundaries.
public enum APWebAuthenticationError: Error, Sendable, Equatable {

    // MARK: - General Errors

    /// A general failure occurred.
    ///
    /// This is a catch-all error for failures that don't fit other categories.
    ///
    /// - Parameters:
    ///   - reason: Human-readable description of the failure
    ///   - responseJSON: Optional JSON response from the server
    case failed(reason: String?, responseJSON: JSON? = nil)

    /// A network connection error occurred.
    ///
    /// This typically indicates no internet connectivity or unreachable server.
    ///
    /// - Parameters:
    ///   - reason: Human-readable description of the connection issue
    ///   - responseJSON: Optional JSON response from the server
    case connectionError(reason: String?, responseJSON: JSON? = nil)

    /// A server-side error occurred (5xx status codes).
    ///
    /// This indicates the server encountered an error processing the request.
    ///
    /// - Parameters:
    ///   - reason: Human-readable description of the server error
    ///   - responseJSON: Optional JSON response from the server
    case serverError(reason: String?, responseJSON: JSON? = nil)

    /// The operation was canceled by the user or system.
    ///
    /// This occurs when a request is explicitly canceled or interrupted.
    case canceled

    /// The requested resource was not found (404 status code).
    ///
    /// This indicates the endpoint or resource doesn't exist.
    case notFound

    /// The request was invalid or malformed (400 status code).
    ///
    /// This indicates the request couldn't be processed due to invalid data.
    case badRequest

    /// An unknown or unexpected error occurred.
    ///
    /// This is used when the error doesn't match any known category.
    case unknown

    /// The request timed out.
    ///
    /// This occurs when the server takes too long to respond.
    case timeout

    // MARK: - Authentication Errors

    /// User feedback or action is required to proceed.
    ///
    /// This occurs when Instagram requires user confirmation or feedback.
    ///
    /// - Parameters:
    ///   - reason: Human-readable description of the required action
    ///   - responseJSON: Optional JSON response with details
    case feedbackRequired(reason: String?, responseJSON: JSON? = nil)

    /// An external action is required (e.g., verify email, phone).
    ///
    /// This occurs when the user must complete an action outside the app.
    ///
    /// - Parameters:
    ///   - reason: Human-readable description of the required action
    ///   - responseJSON: Optional JSON response with action details
    case externalActionRequired(reason: String?, responseJSON: JSON? = nil)

    /// The user's session has expired (web/cookie-based auth).
    ///
    /// This occurs when authentication tokens or cookies are no longer valid.
    ///
    /// - Parameters:
    ///   - reason: Human-readable description of the expiration
    ///   - responseJSON: Optional JSON response from the server
    case sessionExpired(reason: String?, responseJSON: JSON? = nil)

    // MARK: - Rate Limiting & Restrictions

    /// The request was rate limited.
    ///
    /// This occurs when too many requests are made in a short time period.
    ///
    /// - Parameters:
    ///   - reason: Human-readable description of the rate limit
    ///   - responseJSON: Optional JSON response with retry information
    case rateLimit(reason: String?, responseJSON: JSON? = nil)

    // MARK: - Security Checkpoints

    /// A security checkpoint is required (web/cookie-based auth).
    ///
    /// This occurs when Instagram requires additional verification (e.g., CAPTCHA, phone verification).
    ///
    /// - Parameter responseJSON: JSON response containing checkpoint details and URL
    case checkPointRequired(reason: String?, responseJSON: JSON?)

    /// Two-factor authentication is required.
    ///
    /// This occurs when 2FA is enabled and a verification code is needed.
    ///
    /// - Parameter responseJSON: JSON response with 2FA instructions
    case twoFactorRequired(responseJSON: JSON?)

    // MARK: - Response JSON Access

    /// The raw JSON response from the server, if available.
    ///
    /// This property extracts the JSON response from errors that include it.
    /// Useful for debugging and extracting additional error information.
    ///
    /// **Example:**
    /// ```swift
    /// catch let error as APWebAuthenticationError {
    ///     if let json = error.responseJSON {
    ///         print("Server response:", json)
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: The JSON response, or `nil` if not available
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
    ///
    /// Provides short, descriptive titles for each error category.
    ///
    /// **Examples:**
    /// - `"Login Failed"` for login errors
    /// - `"Network Error"` for connection issues
    /// - `"Rate Limit Reached"` for rate limiting
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
    ///
    /// Provides helpful, actionable error messages that guide users on what to do next.
    /// Uses the `reason` parameter if available, otherwise provides a default message.
    ///
    /// - Returns: A localized error description string
    public var errorDescription: String? {
        switch self {

        // MARK: - Session Errors

        case let .sessionExpired(reason, _):
            return reason ?? "Your session has expired. Please log in again."

        // MARK: - Login & Access Errors

        case let .checkPointRequired(reason, json):
            return reason ?? "A security checkpoint is required to continue."

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

        // MARK: - Other Errors

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
    ///
    /// Provides stable identifiers for each error type that can be used in
    /// analytics, logging, and error tracking systems.
    ///
    /// **Examples:**
    /// - `"login_failed"` for login errors
    /// - `"rate_limit"` for rate limiting
    /// - `"checkpoint_required"` for security checks
    ///
    /// - Returns: A string error code, or `nil` if not applicable
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
    ///
    /// Returns `true` for errors that prevent or interrupt authentication:
    /// - Login failed
    /// - Session expired (web or app)
    /// - Feedback required
    /// - Checkpoint required
    ///
    /// **Example:**
    /// ```swift
    /// if error.isLoginError {
    ///     // Redirect to login screen
    ///     showLogin()
    /// }
    /// ```
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
    ///
    /// Returns `true` for errors that may succeed on retry:
    /// - Connection errors
    /// - Timeouts
    /// - Rate limiting (after waiting)
    /// - Server errors (some are temporary)
    ///
    /// **Example:**
    /// ```swift
    /// if error.isRetryable {
    ///     // Show "Try Again" button
    ///     showRetryButton()
    /// }
    /// ```
    public var isRetryable: Bool {
        switch self {
        case .connectionError, .timeout, .rateLimit, .serverError:
            return true
        default:
            return false
        }
    }

    /// Whether this error requires user action to resolve.
    ///
    /// Returns `true` for errors that need the user to do something:
    /// - Checkpoint required
    /// - Two-factor authentication
    /// - Feedback required
    /// - External action required
    /// - App update required
    ///
    /// **Example:**
    /// ```swift
    /// if error.requiresUserAction {
    ///     // Show specific instructions to user
    ///     showActionRequired(error)
    /// }
    /// ```
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
    ///
    /// Returns `true` if the error is `.canceled`, indicating the operation
    /// was intentionally cancelled by the user or system.
    ///
    /// **Example:**
    /// ```swift
    /// catch let error as APWebAuthenticationError {
    ///     if error.isCancelledError {
    ///         // Don't show error UI for user cancellations
    ///         return
    ///     }
    ///     // Show error message
    ///     showError(error)
    /// }
    /// ```
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
    ///
    /// Includes the error code, reason (if available), and indicates if JSON response is present.
    ///
    /// **Example Output:**
    /// ```
    /// APWebAuthenticationError.rateLimit(reason: "Too many requests", hasJSON: true)
    /// ```
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
             let .rateLimit(reason, _):
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

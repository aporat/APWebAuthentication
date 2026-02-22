import Alamofire
import Foundation

// MARK: - Error Extensions

/// Extensions to `Error` for better error handling and Alamofire integration.
///
/// These extensions provide convenient ways to:
/// - Check for network and connection errors
/// - Detect cancelled operations
/// - Extract underlying errors from Alamofire wrappers
/// - Determine if errors should be shown to users
///
/// **Example Usage:**
/// ```swift
/// do {
///     try await performNetworkRequest()
/// } catch {
///     if error.isCancelledError {
///         // User cancelled, don't show error
///         return
///     }
///     
///     if error.isConnectionError {
///         showRetryAlert()
///     } else {
///         showErrorAlert(error.localizedDescription)
///     }
/// }
/// ```
public extension Error {

    // MARK: - Underlying Error Extraction

    /// Safely extracts a `URLError` from the error or its underlying errors.
    ///
    /// Checks both direct URLError instances and URLErrors wrapped inside Alamofire errors.
    ///
    /// **Example:**
    /// ```swift
    /// if let urlError = error.underlyingURLError {
    ///     print("URL error code: \(urlError.code.rawValue)")
    /// }
    /// ```
    ///
    /// - Returns: The URLError if found, or `nil`
    private var underlyingURLError: URLError? {
        // Direct URLError cast
        if let urlError = self as? URLError {
            return urlError
        }

        // Check if wrapped in AFError
        if let afError = self.asAFError,
           let urlError = afError.underlyingError as? URLError {
            return urlError
        }

        return nil
    }

    /// Safely extracts an `APWebAuthenticationError` from the error.
    ///
    /// Checks both direct APWebAuthenticationError instances and those wrapped in Alamofire errors.
    ///
    /// **Example:**
    /// ```swift
    /// if let authError = error.underlyingAuthenticationError {
    ///     switch authError {
    ///     case .checkPointRequired:
    ///         showCheckpointUI()
    ///     case .rateLimit:
    ///         showRateLimitMessage()
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: The APWebAuthenticationError if found, or `nil`
    private var underlyingAuthenticationError: APWebAuthenticationError? {
        // Direct APWebAuthenticationError cast
        if let authError = self as? APWebAuthenticationError {
            return authError
        }

        // Check if wrapped in AFError
        if let afError = self.asAFError,
           let authError = afError.underlyingError as? APWebAuthenticationError {
            return authError
        }

        return nil
    }

    // MARK: - Error Classification

    /// Whether this error represents a network connection issue.
    ///
    /// Returns `true` for common connection problems:
    /// - Timeout
    /// - DNS lookup failed
    /// - Secure connection failed
    /// - Not connected to internet
    /// - Cannot find host
    /// - Network connection lost
    ///
    /// **Example:**
    /// ```swift
    /// catch {
    ///     if error.isConnectionError {
    ///         showAlert("Check your internet connection")
    ///         showRetryButton()
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: `true` if this is a connection error, `false` otherwise
    var isConnectionError: Bool {
        guard let urlError = underlyingURLError else { return false }

        switch urlError.code {
        case .timedOut,
             .dnsLookupFailed,
             .secureConnectionFailed,
             .notConnectedToInternet,
             .cannotFindHost,
             .networkConnectionLost:
            return true
        default:
            return false
        }
    }

    /// Whether this error represents a user-initiated cancellation.
    ///
    /// Checks multiple cancellation sources:
    /// - Alamofire explicit cancellation
    /// - URLError cancellation
    /// - APWebAuthenticationError cancellation cases
    ///
    /// **Example:**
    /// ```swift
    /// catch {
    ///     if error.isCancelledError {
    ///         // Don't show error, user cancelled intentionally
    ///         return
    ///     }
    ///     showError(error)
    /// }
    /// ```
    ///
    /// - Returns: `true` if the operation was cancelled, `false` otherwise
    var isCancelledError: Bool {
        // Check Alamofire's explicit cancellation flag
        if self.asAFError?.isExplicitlyCancelledError == true {
            return true
        }

        // Check URLError cancellation
        if underlyingURLError?.code == .cancelled {
            return true
        }

        // Check APWebAuthenticationError's own cancellation property
        if underlyingAuthenticationError?.isCancelledError == true {
            return true
        }

        return false
    }

    /// Whether this error can be safely ignored from a user-facing perspective.
    ///
    /// Returns `true` for errors that don't need user alerts:
    /// - Connection errors (user knows their internet is down)
    /// - Cancelled errors (user cancelled intentionally)
    ///
    /// **Example:**
    /// ```swift
    /// catch {
    ///     if error.isIgnorableError {
    ///         // Log but don't show alert
    ///         logger.debug("Ignorable error: \(error)")
    ///     } else {
    ///         showErrorAlert(error.localizedDescription)
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: `true` if the error can be ignored, `false` if it should be shown to the user
    var isIgnorableError: Bool {
        isConnectionError || isCancelledError
    }

    // MARK: - Error Information

    /// Returns a user-friendly description of the error.
    ///
    /// Attempts to extract the most informative error message by checking:
    /// 1. `LocalizedError.errorDescription`
    /// 2. `APWebAuthenticationError.errorDescription`
    /// 3. `AFError` description
    /// 4. Standard `localizedDescription`
    ///
    /// **Example:**
    /// ```swift
    /// catch {
    ///     showAlert(title: "Error", message: error.userFriendlyDescription)
    /// }
    /// ```
    ///
    /// - Returns: A user-friendly error description
    var userFriendlyDescription: String {
        // Check for LocalizedError first
        if let localizedError = self as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        // Check for APWebAuthenticationError
        if let authError = underlyingAuthenticationError {
            return authError.errorDescription ?? authError.localizedDescription
        }

        // Check for AFError
        if let afError = self.asAFError {
            return afError.localizedDescription
        }

        // Fallback to standard description
        return localizedDescription
    }
}

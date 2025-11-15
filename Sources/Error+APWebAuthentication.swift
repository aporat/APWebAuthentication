import Foundation
import Alamofire

// MARK: - Error Extensions
public extension Error {
    
    /// A private helper that safely unwraps and returns a `URLError` regardless of whether
    /// the error is a direct `URLError` or is wrapped inside an `AFError`.
    private var underlyingURLError: URLError? {
        // First, try to cast `self` directly to a URLError.
        // If that fails, check if `self` is an AFError and if its underlyingError is a URLError.
        self as? URLError ?? asAFError?.underlyingError as? URLError
    }

    /// A private helper that safely unwraps and returns an `APWebAuthenticationError`.
    private var underlyingAuthenticationError: APWebAuthenticationError? {
        self as? APWebAuthenticationError ?? asAFError?.underlyingError as? APWebAuthenticationError
    }
    
    /// Checks if the error is a common network connection-related issue.
    var isConnectionError: Bool {
        guard let urlError = underlyingURLError else { return false }
        
        // Use a switch statement for a cleaner, more readable check.
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

    /// Checks if the error represents a user-initiated cancellation.
    var isCancelledError: Bool {
        // Check for Alamofire's explicit cancellation flag first.
        if self.asAFError?.isExplicitlyCancelledError == true {
            return true
        }

        // Check for the standard URLError cancellation code.
        if underlyingURLError?.code == .cancelled {
            return true
        }
        
        // Check for custom cancellation errors from your app.
        if let authError = underlyingAuthenticationError {
            switch authError {
            case .canceled, .badRequest, .unknown:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    /// A convenience property to determine if an error is likely safe to ignore
    /// from a user-facing perspective (e.g., no need to show an alert).
    var isIgnorableError: Bool {
        isConnectionError || isCancelledError
    }
}

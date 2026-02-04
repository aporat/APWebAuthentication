import Foundation
import SwiftyBeaver
@preconcurrency import SwiftyJSON

// MARK: - Redirect Handler

/// Handles redirect URL detection and response parsing for web authentication.
///
/// This class is responsible for:
/// - Detecting when a navigation matches the configured redirect URL
/// - Parsing query parameters and fragments from redirect URLs
/// - Parsing JSON responses from web pages
/// - Extracting error messages from various response formats
///
/// **Example Usage:**
/// ```swift
/// let handler = WebAuthRedirectHandler(redirectURL: URL(string: "myapp://callback")!)
///
/// // Check if URL is a redirect
/// if let result = handler.checkRedirect(url: someURL) {
///     switch result {
///     case .success(let params):
///         print("Auth succeeded:", params)
///     case .failure(let error):
///         print("Auth failed:", error)
///     }
/// }
/// ```
@MainActor
public final class WebAuthRedirectHandler {

    // MARK: - Public Properties

    /// The redirect URL to monitor for authentication completion
    public let redirectURL: URL?

    // MARK: - Initialization

    /// Creates a new redirect handler.
    ///
    /// - Parameter redirectURL: The callback URL that signals authentication completion
    public init(redirectURL: URL?) {
        self.redirectURL = redirectURL
    }

    // MARK: - Redirect Detection

    /// Checks if a URL matches the redirect URL and extracts the response.
    ///
    /// This method compares the given URL against the configured redirect URL.
    /// If they match, it parses the URL to extract authentication data from
    /// query parameters and fragments.
    ///
    /// - Parameter url: The URL to check
    /// - Returns: A result containing parsed parameters on success, or an error on failure.
    ///            Returns `nil` if the URL doesn't match the redirect URL.
    ///
    /// **Example:**
    /// ```swift
    /// // Redirect URL: myapp://callback
    /// // Navigation URL: myapp://callback?code=abc123&state=xyz
    ///
    /// if let result = handler.checkRedirect(url: navigationURL) {
    ///     switch result {
    ///     case .success(let params):
    ///         let code = params["code"] // "abc123"
    ///         let state = params["state"] // "xyz"
    ///     case .failure(let error):
    ///         print(error.errorDescription)
    ///     }
    /// }
    /// ```
    public func checkRedirect(url: URL?) -> Result<[String: any Sendable]?, APWebAuthenticationError>? {
        guard let url = url,
              let currentRedirectURL = redirectURL?.absoluteString,
              !currentRedirectURL.isEmpty else {
            return nil
        }

        log.debug("🔍 Checking Redirect: URL: \(url.absoluteString) vs Redirect: \(currentRedirectURL)")

        guard url.absoluteString.hasPrefix(currentRedirectURL) else {
            return nil
        }

        log.info("✅ Redirect URL MATCH detected: \(url.absoluteString)")

        return url.getResponse()
    }

    // MARK: - JSON Parsing

    /// Parses a JSON response and extracts any error messages.
    ///
    /// This method looks for error messages in various common locations
    /// within the JSON structure:
    /// - `meta.error_message`
    /// - `error_message`
    /// - `error`
    /// - `message` (when status is "failure")
    ///
    /// - Parameter jsonString: The JSON string to parse
    /// - Returns: An error if one is found in the JSON, or `nil` if no error
    ///
    /// **Example JSON formats handled:**
    /// ```json
    /// // Format 1: meta.error_message
    /// {
    ///   "meta": {
    ///     "error_message": "Invalid credentials"
    ///   }
    /// }
    ///
    /// // Format 2: error_message
    /// {
    ///   "error_message": "Rate limit exceeded"
    /// }
    ///
    /// // Format 3: error
    /// {
    ///   "error": "Not authorized"
    /// }
    ///
    /// // Format 4: status + message
    /// {
    ///   "status": "failure",
    ///   "message": "Account suspended"
    /// }
    /// ```
    public func parseJSONError(from jsonString: String) -> APWebAuthenticationError? {
        let response = JSON(parseJSON: jsonString)
        var errorMessage: String?

        // Check various common error message locations
        if let msg = response["meta"]["error_message"].string {
            errorMessage = msg
        } else if let msg = response["error_message"].string {
            errorMessage = msg
        } else if let msg = response["error"].string {
            errorMessage = msg
        } else if response["status"].string == "failure",
                  let msg = response["message"].string {
            errorMessage = msg
        }

        if let finalMessage = errorMessage, !finalMessage.isEmpty {
            return .failed(reason: finalMessage)
        }

        return nil
    }
}

// MARK: - URL Response Parsing

private extension URL {

    /// Extracts authentication response data from URL query parameters and fragments.
    ///
    /// This method parses both the query string and URL fragment to extract
    /// authentication data. It checks for errors and returns appropriate results.
    ///
    /// **Supported formats:**
    /// - OAuth 2.0: `?code=...&state=...` or `#access_token=...&token_type=...`
    /// - Error responses: `?error=...&error_description=...`
    /// - Custom parameters in query or fragment
    ///
    /// - Returns: A result containing parsed parameters or an error
    func getResponse() -> Result<[String: any Sendable]?, APWebAuthenticationError> {
        var params = [String: any Sendable]()

        // Parse query parameters
        if let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                params[item.name] = item.value
            }
        }

        // Parse fragment parameters (for OAuth implicit flow)
        if let fragment = self.fragment {
            let fragmentParams = parseFragment(fragment)
            params.merge(fragmentParams) { _, new in new }
        }

        // Check for errors
        if let error = params["error"] as? String {
            let description = params["error_description"] as? String
            return .failure(.failed(reason: description ?? error))
        }

        // If we have parameters, return success
        if !params.isEmpty {
            return .success(params)
        }

        // No parameters found
        return .success(nil)
    }

    /// Parses a URL fragment into key-value pairs.
    ///
    /// URL fragments in OAuth responses often contain authentication data:
    /// `#access_token=abc123&token_type=Bearer&expires_in=3600`
    ///
    /// - Parameter fragment: The fragment string (without the # symbol)
    /// - Returns: A dictionary of parsed key-value pairs
    private func parseFragment(_ fragment: String) -> [String: any Sendable] {
        var params = [String: any Sendable]()

        let pairs = fragment.components(separatedBy: "&")
        for pair in pairs {
            let components = pair.components(separatedBy: "=")
            if components.count == 2 {
                let key = components[0]
                let value = components[1].removingPercentEncoding ?? components[1]
                params[key] = value
            }
        }

        return params
    }
}

import Foundation

// MARK: - URL Extension for Web Authentication

/// Extensions to `URL` for web authentication and OAuth workflows.
///
/// This extension provides utilities for:
/// - OAuth URL manipulation and signature generation
/// - URL scheme validation
/// - Parameter extraction from query strings and fragments
/// - Authentication response parsing
///
/// **Common Use Cases:**
/// ```swift
/// // Extract parameters from callback URL
/// let params = callbackURL.parameters
/// let token = params["access_token"]
///
/// // Check if URL is web-accessible
/// if url.isWebURL() {
///     // Load in web view
/// }
///
/// // Parse authentication response
/// switch callbackURL.getResponse() {
/// case .success(let data):
///     print("Auth succeeded:", data)
/// case .failure(let error):
///     print("Auth failed:", error)
/// }
/// ```
public extension URL {
    
    // MARK: - OAuth Utilities
    
    /// The normalized base URL for OAuth 1.0 signature generation.
    ///
    /// Returns a URL string suitable for OAuth 1.0 signature calculation according
    /// to RFC 5849 (The OAuth 1.0 Protocol). This normalized form:
    /// - Excludes the query string
    /// - Excludes the fragment identifier
    /// - Excludes user credentials (username/password)
    /// - Excludes default ports (80 for HTTP, 443 for HTTPS)
    ///
    /// **OAuth Signature Base String:**
    ///
    /// According to RFC 5849 Section 3.4.1.2, the base string URI is constructed by:
    /// 1. Setting the scheme and host to lowercase
    /// 2. Including the port only if it's not the default for the scheme
    /// 3. Excluding the query and fragment components
    ///
    /// **Example:**
    /// ```swift
    /// let url = URL(string: "https://api.twitter.com:443/oauth/request_token?foo=bar#section")!
    /// print(url.oAuthBaseURL)
    /// // Output: "https://api.twitter.com/oauth/request_token"
    /// ```
    ///
    /// - Returns: The normalized base URL string, or `nil` if the URL cannot be parsed
    ///
    /// - Note: `URLComponents` automatically handles port normalization,
    ///         removing default ports when converting to string.
    var oAuthBaseURL: String? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        // Remove components not included in OAuth base string
        components.query = nil
        components.fragment = nil
        components.user = nil
        components.password = nil
        
        // URLComponents automatically omits default ports (80 for http, 443 for https)
        // when generating the string, simplifying the logic.
        return components.string
    }
    
    // MARK: - URL Validation
    
    /// Determines whether the URL uses a web-compatible scheme.
    ///
    /// Checks if the URL's scheme is either `http` or `https`, indicating
    /// it can be loaded in a web view or browser. Useful for validating URLs
    /// before presenting web authentication interfaces.
    ///
    /// **Example:**
    /// ```swift
    /// let webURL = URL(string: "https://example.com")!
    /// let appURL = URL(string: "myapp://callback")!
    ///
    /// print(webURL.isWebURL())  // true
    /// print(appURL.isWebURL())  // false
    /// ```
    ///
    /// **Use Cases:**
    /// - Validating authentication URLs before loading
    /// - Determining whether to open in Safari vs. custom handler
    /// - Filtering web-compatible links from deep links
    ///
    /// - Returns: `true` if the scheme is HTTP or HTTPS (case-insensitive), `false` otherwise
    ///
    /// - Note: Returns `false` for URLs without a scheme
    func isWebURL() -> Bool {
        guard let scheme = self.scheme?.lowercased() else {
            return false
        }
        return ["http", "https"].contains(scheme)
    }
    
    // MARK: - URL Manipulation
    
    /// Creates a new URL with the scheme component removed.
    ///
    /// Returns a modified version of the URL without its scheme, which can be
    /// useful for URL comparison or manipulation in authentication flows.
    ///
    /// **Example:**
    /// ```swift
    /// let url = URL(string: "https://example.com/path?query=value")!
    /// print(url.withoutScheme?.absoluteString)
    /// // Output: "//example.com/path?query=value"
    /// ```
    ///
    /// **Use Cases:**
    /// - Comparing URLs regardless of HTTP/HTTPS
    /// - Building relative URLs
    /// - Protocol-agnostic URL matching
    ///
    /// - Returns: A new URL without the scheme, or `nil` if URL components cannot be created
    ///
    /// - Note: The resulting URL string will start with `//` followed by the host
    var withoutScheme: URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = nil
        return components?.url
    }
    // MARK: - Parameter Extraction
    
    /// Extracts all parameters from the URL's query string and fragment.
    ///
    /// This property parses both the query string and fragment identifier to extract
    /// key-value pairs. This is essential for OAuth and web authentication flows where
    /// parameters can be passed in either location.
    ///
    /// **Parsing Rules:**
    /// - Parameters from both query (`?key=value`) and fragment (`#key=value`) are included
    /// - When a key appears in both locations, the fragment value takes precedence
    /// - URL-encoded values are preserved as-is (not decoded)
    /// - Parameters without values are included with empty string values
    ///
    /// **Example:**
    /// ```swift
    /// // Standard query parameters
    /// let url1 = URL(string: "myapp://callback?code=abc123&state=xyz")!
    /// print(url1.parameters)
    /// // ["code": "abc123", "state": "xyz"]
    ///
    /// // Fragment parameters (common in OAuth implicit flow)
    /// let url2 = URL(string: "myapp://callback#access_token=abc&expires_in=3600")!
    /// print(url2.parameters)
    /// // ["access_token": "abc", "expires_in": "3600"]
    ///
    /// // Combined (fragment takes precedence)
    /// let url3 = URL(string: "myapp://callback?token=old#token=new")!
    /// print(url3.parameters["token"])
    /// // "new"
    /// ```
    ///
    /// **OAuth Flows:**
    /// - **Authorization Code Flow**: Parameters in query string (`?code=...`)
    /// - **Implicit Flow**: Parameters in fragment (`#access_token=...`)
    /// - **Error Responses**: Can use either location
    ///
    /// - Returns: A dictionary of parameter name-value pairs
    ///
    /// - Note: Returns an empty dictionary if the URL has no parameters
    var parameters: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return [:]
        }
        
        // Parse the main query string
        let queryParams = components.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        } ?? [:]
        
        // Also parse the fragment, as it's often used in OAuth redirects
        var fragmentParams: [String: String] = [:]
        if let fragment = components.fragment,
           let fragmentComponents = URLComponents(string: "?\(fragment)") {
            fragmentParams = fragmentComponents.queryItems?.reduce(into: [String: String]()) { result, item in
                result[item.name] = item.value
            } ?? [:]
        }
        
        // Merge the two, with fragment values overwriting query values for duplicate keys.
        return queryParams.merging(fragmentParams, uniquingKeysWith: { _, new in new })
    }
    // MARK: - Authentication Response Parsing
    
    /// Parses the URL as an authentication callback to determine success or failure.
    ///
    /// This method analyzes the URL's parameters to detect authentication results,
    /// following common OAuth and web authentication conventions. It checks for
    /// standard error parameters and returns appropriate error types.
    ///
    /// **Error Detection:**
    ///
    /// The method checks for errors in this order of precedence:
    /// 1. `error_description` - Detailed error message (OAuth 2.0 standard)
    /// 2. `error_message` - Alternative error message format
    /// 3. `error` - Basic error indicator
    ///
    /// **Error Type Mapping:**
    /// - If `error_type=login_failed`: Returns `.loginFailed`
    /// - For any other error: Returns `.failed`
    /// - No error detected: Returns `.success` with all parameters
    ///
    /// **Example Usage:**
    /// ```swift
    /// // Success response
    /// let successURL = URL(string: "myapp://callback?code=abc123&state=xyz")!
    /// switch successURL.getResponse() {
    /// case .success(let params):
    ///     let code = params["code"] // "abc123"
    ///     // Exchange code for token
    /// case .failure(let error):
    ///     print("Error:", error)
    /// }
    ///
    /// // Error response
    /// let errorURL = URL(string: "myapp://callback?error=access_denied&error_description=User+cancelled")!
    /// switch errorURL.getResponse() {
    /// case .success:
    ///     // Won't reach here
    ///     break
    /// case .failure(let error):
    ///     print(error.errorDescription) // "User cancelled"
    /// }
    ///
    /// // Login failure
    /// let loginURL = URL(string: "myapp://callback?error_type=login_failed&error=Invalid+credentials")!
    /// if case .failure(.loginFailed(let reason, _)) = loginURL.getResponse() {
    ///     print(reason) // "Invalid credentials"
    /// }
    /// ```
    ///
    /// **OAuth 2.0 Error Responses:**
    ///
    /// According to RFC 6749, OAuth 2.0 error responses include:
    /// - `error`: Error code (e.g., "access_denied", "invalid_request")
    /// - `error_description`: Human-readable error description
    /// - `error_uri`: Optional URI with error information
    ///
    /// **Text Processing:**
    ///
    /// Error messages are automatically cleaned:
    /// - Plus signs (`+`) are converted to spaces
    /// - Percent-encoding is removed (e.g., `%20` → space)
    ///
    /// - Returns: A `Result` containing either:
    ///   - `.success`: Dictionary of all URL parameters
    ///   - `.failure`: An `APWebAuthenticationError` with error details
    ///
    /// - Note: This method is compatible with the refactored `APWebAuthenticationError`
    ///         where the `responseJSON` parameter defaults to `nil`.
    func getResponse() -> Result<[String: String], APWebAuthenticationError> {
        let params = self.parameters

        // Check for various error keys used in OAuth and other APIs.
        let errorReason = params["error_description"] ?? params["error_message"] ?? params["error"]
        
        if let reason = errorReason?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding {
            // Check for specific error types
            if params["error_type"] == "login_failed" {
                return .failure(.loginFailed(reason: reason))
            }
            
            // Generic failure for other errors
            return .failure(.failed(reason: reason))
        }

        // No error detected - return all parameters as success
        return .success(params)
    }
}

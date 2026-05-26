import Foundation

// MARK: - URL Extension for Web Authentication

/// Extensions to `URL` for web authentication and OAuth workflows.
///
/// Provides utilities for OAuth URL manipulation, parameter extraction,
/// and authentication response parsing.
///
/// **Example:**
/// ```swift
/// // Extract parameters from callback URL
/// let token = callbackURL.parameters["access_token"]
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
    /// Returns a URL string suitable for OAuth 1.0 signature calculation (RFC 5849).
    /// Excludes query string, fragment, user credentials, and default ports.
    ///
    /// **Example:**
    /// ```swift
    /// let url = URL(string: "https://api.twitter.com:443/oauth/request_token?foo=bar")!
    /// print(url.oAuthBaseURL)
    /// // "https://api.twitter.com/oauth/request_token"
    /// ```
    var oAuthBaseURL: String? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }

        // Remove components not included in OAuth base string
        components.query = nil
        components.fragment = nil
        components.user = nil
        components.password = nil

        // RFC 5849 §3.4.1.2: scheme and host MUST be lowercase; default ports
        // (80/http, 443/https) MUST be omitted. URLComponents only suppresses
        // the port when it was never set explicitly, so strip it ourselves
        // when the original URL embedded `:80` / `:443` literally.
        let scheme = components.scheme?.lowercased()
        components.scheme = scheme
        components.host = components.host?.lowercased()
        if let port = components.port,
           (scheme == "http" && port == 80) || (scheme == "https" && port == 443) {
            components.port = nil
        }

        return components.string
    }

    // MARK: - URL Validation

    /// Determines whether the URL uses a web-compatible scheme (http/https).
    ///
    /// - Returns: True if the scheme is HTTP or HTTPS (case-insensitive)
    func isWebURL() -> Bool {
        guard let scheme = self.scheme?.lowercased() else {
            return false
        }
        return ["http", "https"].contains(scheme)
    }

    // MARK: - URL Manipulation

    /// Creates a new URL with the scheme component removed.
    ///
    /// - Returns: A new URL without the scheme, or nil if invalid
    var withoutScheme: URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = nil
        return components?.url
    }

    // MARK: - Parameter Extraction

    /// Extracts all parameters from the URL's query string and fragment.
    ///
    /// Parses both query (`?key=value`) and fragment (`#key=value`) parameters.
    /// Fragment values take precedence for duplicate keys.
    ///
    /// **Example:**
    /// ```swift
    /// // Query parameters
    /// let url1 = URL(string: "myapp://callback?code=abc123&state=xyz")!
    /// print(url1.parameters) // ["code": "abc123", "state": "xyz"]
    ///
    /// // Fragment parameters (OAuth implicit flow)
    /// let url2 = URL(string: "myapp://callback#access_token=abc&expires_in=3600")!
    /// print(url2.parameters) // ["access_token": "abc", "expires_in": "3600"]
    /// ```
    var parameters: [String: String] {
        // Collapse to a dictionary for the common-case API. Use
        // ``parameterItems`` when duplicates must be preserved (OAuth signing).
        var result: [String: String] = [:]
        for (name, value) in parameterItems {
            result[name] = value
        }
        return result
    }

    /// Ordered list of every query and fragment parameter, preserving order
    /// and duplicate keys.
    ///
    /// OAuth 1.0a signing (RFC 5849 §3.4.1.3.2) requires every value of a
    /// repeated parameter to participate in the signature base string; use
    /// this property instead of ``parameters`` whenever a parameter may legally
    /// appear more than once (e.g. `scope=a&scope=b`).
    var parameterItems: [(String, String)] {
        var items: [(String, String)] = []

        if let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                items.append((item.name, item.value ?? ""))
            }
        }

        if let fragment = self.fragment {
            items.append(contentsOf: Self.parseFormURLEncoded(fragment))
        }

        return items
    }

    /// Parses an `application/x-www-form-urlencoded` string into ordered
    /// key/value pairs. Performs `+` → space substitution and percent
    /// decoding on each side of the `=` independently so that embedded
    /// reserved characters survive the round trip — `URLComponents(string:)`
    /// is not safe to reuse here because fragments and bodies may contain
    /// characters it interprets as delimiters.
    static func parseFormURLEncoded(_ body: String) -> [(String, String)] {
        var items: [(String, String)] = []
        for pair in body.components(separatedBy: "&") where !pair.isEmpty {
            let rawName: String
            let rawValue: String
            if let separator = pair.firstIndex(of: "=") {
                rawName = String(pair[..<separator])
                rawValue = String(pair[pair.index(after: separator)...])
            } else {
                rawName = pair
                rawValue = ""
            }
            let name = rawName
                .replacingOccurrences(of: "+", with: " ")
                .removingPercentEncoding ?? rawName
            let value = rawValue
                .replacingOccurrences(of: "+", with: " ")
                .removingPercentEncoding ?? rawValue
            items.append((name, value))
        }
        return items
    }

    // MARK: - Authentication Response Parsing

    /// Parses the URL as an authentication callback to determine success or failure.
    ///
    /// Checks for standard OAuth error parameters and returns appropriate results.
    ///
    /// **Error Detection Priority:**
    /// 1. `error_description` - Detailed error message
    /// 2. `error_message` - Alternative error format
    /// 3. `error` - Basic error indicator
    ///
    /// **Example:**
    /// ```swift
    /// // Success
    /// let url = URL(string: "myapp://callback?code=abc123")!
    /// if case .success(let params) = url.getResponse() {
    ///     let code = params["code"]
    /// }
    ///
    /// // Error
    /// let errorURL = URL(string: "myapp://callback?error=access_denied")!
    /// if case .failure(let error) = errorURL.getResponse() {
    ///     print(error.errorDescription)
    /// }
    /// ```
    ///
    /// - Returns: Result containing either parameters or an authentication error
    func getResponse() -> Result<[String: String], APWebAuthenticationError> {
        let params = self.parameters

        // Check for error parameters
        let errorReason = params["error_description"] ?? params["error_message"] ?? params["error"]

        if let reason = errorReason?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding {
            // Check for specific error types
            if params["error_type"] == "login_failed" {
                return .failure(.sessionExpired(reason: reason))
            }

            // Generic failure
            return .failure(.failed(reason: reason))
        }

        // No error - return all parameters as success
        return .success(params)
    }
}

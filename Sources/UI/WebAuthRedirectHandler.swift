import Foundation
@preconcurrency import SwiftyJSON

// MARK: - Redirect Handler

/// Handles redirect URL detection and response parsing for web authentication.
///
/// This class is responsible for:
/// - Detecting when a navigation matches the configured redirect URL
/// - Validating the OAuth `state` parameter (CSRF protection) when one was
///   supplied for the flow
/// - Parsing query parameters and fragments from redirect URLs
/// - Parsing JSON responses from web pages
/// - Extracting error messages from various response formats
///
/// **Example Usage:**
/// ```swift
/// let state = WebAuthRedirectHandler.generateState()
/// let handler = WebAuthRedirectHandler(
///     redirectURL: URL(string: "myapp://callback")!,
///     expectedState: state
/// )
///
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

    /// The `state` value that must be echoed back by the authorization server.
    ///
    /// When non-nil, every callback (including ones that carry an `error=`
    /// parameter) must include a matching `state`. A missing or mismatched
    /// state is rejected as a CSRF attempt. Leave `nil` to skip validation —
    /// only do this for flows that genuinely do not use a state parameter.
    public var expectedState: String?

    // MARK: - Initialization

    /// Creates a new redirect handler.
    ///
    /// - Parameters:
    ///   - redirectURL: The callback URL that signals authentication completion
    ///   - expectedState: Optional `state` value to validate on the callback
    public init(redirectURL: URL?, expectedState: String? = nil) {
        self.redirectURL = redirectURL
        self.expectedState = expectedState
    }

    // MARK: - State Generation

    /// Generates a cryptographically random `state` value suitable for OAuth
    /// CSRF protection.
    ///
    /// - Returns: 32 bytes of random data, URL-safe base64 encoded.
    public static func generateState() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Redirect Detection

    /// Checks if a URL matches the redirect URL and extracts the response.
    ///
    /// The URL is compared against `redirectURL` by **components** (scheme,
    /// host, port, path) — not by string prefix — so callbacks like
    /// `myapp://callback.attacker.com` cannot impersonate `myapp://callback`.
    ///
    /// If `expectedState` is set, the callback's `state` parameter must match
    /// exactly; otherwise this returns `.failure(.failed)` even when the
    /// authorization server claims success.
    ///
    /// - Parameter url: The URL to check
    /// - Returns: A result containing parsed parameters on success, or an
    ///            error on failure. Returns `nil` if the URL doesn't match
    ///            the redirect URL.
    public func checkRedirect(url: URL?) -> Result<[String: any Sendable]?, APWebAuthenticationError>? {
        guard let url, let redirectURL else { return nil }
        guard Self.urlMatchesRedirect(url, redirect: redirectURL) else {
            return nil
        }

        // CSRF protection: when a state was generated for this flow, every
        // callback must echo it back — even ones that carry an `error=`
        // parameter, since an attacker can forge those too.
        if let expectedState, !expectedState.isEmpty {
            let receivedState = Self.parameterValue(named: "state", in: url)
            guard let receivedState, receivedState == expectedState else {
                return .failure(.failed(reason: "OAuth state mismatch — possible CSRF."))
            }
        }

        // Delegate to the single source-of-truth response parser.
        switch url.getResponse() {
        case .success(let params):
            if params.isEmpty {
                return .success(nil)
            }
            var sendableParams: [String: any Sendable] = [:]
            for (key, value) in params {
                sendableParams[key] = value
            }
            return .success(sendableParams)
        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - URL Matching

    /// Matches a candidate URL against the registered redirect URL by
    /// comparing scheme (case-insensitive), host (case-insensitive), port
    /// and path. Query and fragment are intentionally ignored.
    static func urlMatchesRedirect(_ url: URL, redirect: URL) -> Bool {
        guard let candidate = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let target = URLComponents(url: redirect, resolvingAgainstBaseURL: false) else {
            return false
        }

        guard candidate.scheme?.lowercased() == target.scheme?.lowercased(),
              candidate.host?.lowercased() == target.host?.lowercased(),
              candidate.port == target.port else {
            return false
        }

        // Treat empty path and "/" as equivalent — URLComponents reports
        // `"https://example.com"` with an empty path.
        let candidatePath = candidate.path.isEmpty ? "/" : candidate.path
        let targetPath = target.path.isEmpty ? "/" : target.path
        return candidatePath == targetPath
    }

    /// Returns the value of the named parameter from the URL's query string
    /// or fragment. Used for state extraction before full response parsing.
    private static func parameterValue(named name: String, in url: URL) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let value = components.queryItems?.first(where: { $0.name == name })?.value {
            return value
        }

        guard let fragment = url.fragment else { return nil }
        for pair in fragment.components(separatedBy: "&") {
            let parts = pair.components(separatedBy: "=")
            guard parts.count == 2, parts[0] == name else { continue }
            return parts[1].removingPercentEncoding ?? parts[1]
        }
        return nil
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


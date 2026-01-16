import Foundation

// MARK: - String Extensions for Web Authentication

/// Extensions to `String` for web authentication, OAuth, and JavaScript interoperability.
///
/// This extension provides string manipulation utilities for:
/// - JavaScript string escaping for injection into web views
/// - URL percent-encoding compliant with RFC 3986 (OAuth 1.0)
/// - URL percent-decoding
/// - Query string parameter parsing
///
/// **Common Use Cases:**
/// ```swift
/// // JavaScript injection
/// let jsCode = "alert('\(userInput.javascriptEscaped)');"
/// webView.evaluateJavaScript(jsCode)
///
/// // OAuth parameter encoding
/// let oauthParam = "hello world!".urlEscaped  // "hello%20world%21"
///
/// // Parse query string
/// let params = "code=abc123&state=xyz".urlQueryParameters
/// print(params["code"])  // "abc123"
/// ```
public extension String {
    
    // MARK: - JavaScript Escaping
    
    /// Returns a string with characters properly escaped for JavaScript string literals.
    ///
    /// This property escapes characters that have special meaning in JavaScript strings,
    /// making it safe to inject dynamic content into JavaScript code executed in web views.
    /// Essential for preventing JavaScript injection attacks and syntax errors.
    ///
    /// **Escaped Characters:**
    /// - `\` → `\\` (backslash)
    /// - `"` → `\"` (double quote)
    /// - `\n` → `\\n` (line feed)
    /// - `\r` → `\\r` (carriage return)
    /// - `\u{2028}` → `\\u2028` (line separator)
    /// - `\u{2029}` → `\\u2029` (paragraph separator)
    ///
    /// **Why Line/Paragraph Separators?**
    ///
    /// Unicode characters U+2028 and U+2029 are treated as line terminators in JavaScript,
    /// but not in JSON or Swift strings. Without escaping them, they can cause unexpected
    /// behavior or syntax errors when injecting strings into JavaScript contexts.
    ///
    /// **Example Usage:**
    /// ```swift
    /// // Unsafe - potential injection vulnerability
    /// let userInput = "Robert'); alert('XSS"
    /// let badJS = "showName('\(userInput)');"  // Syntax error or injection!
    ///
    /// // Safe - properly escaped
    /// let goodJS = "showName('\(userInput.javascriptEscaped)');"
    /// webView.evaluateJavaScript(goodJS)  // Executes safely
    ///
    /// // Newlines and special characters
    /// let multiline = "Line 1\nLine 2\rLine 3"
    /// print(multiline.javascriptEscaped)
    /// // Output: "Line 1\\nLine 2\\rLine 3"
    ///
    /// // Unicode line separators
    /// let unicode = "First\u{2028}Second\u{2029}Third"
    /// print(unicode.javascriptEscaped)
    /// // Output: "First\\u2028Second\\u2029Third"
    /// ```
    ///
    /// **Security Note:**
    ///
    /// While this escaping prevents syntax errors and basic injection, always validate
    /// and sanitize user input. Consider using `WKWebView`'s message handlers or
    /// `evaluateJavaScript` with properly structured data instead of string concatenation
    /// when possible.
    ///
    /// - Returns: A new string with JavaScript-unsafe characters escaped
    ///
    /// - Complexity: O(n) where n is the length of the string
    var javascriptEscaped: String {
        var escaped = self
        
        // Order matters: backslash must be escaped first to avoid double-escaping
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
        
        // Unicode line terminators that JavaScript treats specially
        escaped = escaped.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
        escaped = escaped.replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        
        return escaped
    }
    
    // MARK: - URL Encoding
    
    /// Returns a percent-encoded string following RFC 3986 for OAuth 1.0 compliance.
    ///
    /// This property encodes the string using the "unreserved" character set defined
    /// in RFC 3986 Section 2.3. This is stricter than standard URL encoding and is
    /// required for OAuth 1.0a signature generation, where even characters like
    /// `/`, `?`, and `=` must be encoded.
    ///
    /// **Unreserved Characters (not encoded):**
    /// - Letters: `A-Z`, `a-z`
    /// - Digits: `0-9`
    /// - Special: `-`, `.`, `_`, `~`
    ///
    /// **All other characters are percent-encoded**, including:
    /// - Spaces → `%20`
    /// - Reserved URI characters: `/`, `?`, `#`, `[`, `]`, `@`, `!`, `$`, `&`, `'`, `(`, `)`, `*`, `+`, `,`, `;`, `=`
    /// - Unicode characters → `%XX%XX...` (UTF-8 bytes)
    ///
    /// **Example Usage:**
    /// ```swift
    /// // Basic encoding
    /// let text = "hello world"
    /// print(text.urlEscaped)  // "hello%20world"
    ///
    /// // Reserved characters
    /// let url = "https://example.com/path?query=value"
    /// print(url.urlEscaped)
    /// // "https%3A%2F%2Fexample.com%2Fpath%3Fquery%3Dvalue"
    ///
    /// // Special characters
    /// let special = "email+tag@example.com"
    /// print(special.urlEscaped)
    /// // "email%2Btag%40example.com"
    ///
    /// // Unicode
    /// let unicode = "Hello 世界 🌍"
    /// print(unicode.urlEscaped)
    /// // "Hello%20%E4%B8%96%E7%95%8C%20%F0%9F%8C%8D"
    /// ```
    ///
    /// **OAuth 1.0 Usage:**
    /// ```swift
    /// // Building OAuth signature base string
    /// let method = "POST"
    /// let url = "https://api.twitter.com/oauth/request_token".urlEscaped
    /// let params = "oauth_consumer_key=xyz&oauth_nonce=abc".urlEscaped
    /// let baseString = "\(method)&\(url)&\(params)"
    /// ```
    ///
    /// **Comparison with Standard Encoding:**
    /// ```swift
    /// let text = "hello/world"
    ///
    /// // Standard URL encoding (URLComponents default)
    /// // Forward slash is NOT encoded: "hello/world"
    ///
    /// // RFC 3986 encoding (this property)
    /// print(text.urlEscaped)  // "hello%2Fworld"
    /// ```
    ///
    /// - Returns: The percent-encoded string, or the original string if encoding fails
    ///
    /// - Note: This encoding is more aggressive than `addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)`
    ///
    /// - SeeAlso: [RFC 3986 Section 2.3](https://tools.ietf.org/html/rfc3986#section-2.3)
    var urlEscaped: String {
        // The "unreserved" character set is defined in RFC 3986 Section 2.3.
        // ALPHA / DIGIT / "-" / "." / "_" / "~"
        let unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        let allowed = CharacterSet(charactersIn: unreserved)
        
        return self.addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
    
    /// Returns a string with percent-encoding removed.
    ///
    /// This property safely decodes percent-encoded characters (e.g., `%20` → space),
    /// converting the string back to its original form. If the string cannot be
    /// decoded (malformed encoding), returns the original string unchanged.
    ///
    /// **Example Usage:**
    /// ```swift
    /// // Basic decoding
    /// let encoded = "hello%20world"
    /// print(encoded.urlUnescaped)  // "hello world"
    ///
    /// // Special characters
    /// let encoded2 = "email%2Btag%40example.com"
    /// print(encoded2.urlUnescaped)  // "email+tag@example.com"
    ///
    /// // Unicode
    /// let encoded3 = "Hello%20%E4%B8%96%E7%95%8C"
    /// print(encoded3.urlUnescaped)  // "Hello 世界"
    ///
    /// // Already decoded or malformed - returns original
    /// let plain = "hello world"
    /// print(plain.urlUnescaped)  // "hello world"
    /// ```
    ///
    /// **Common Use Cases:**
    /// - Decoding URL parameters extracted from callback URLs
    /// - Processing error messages from OAuth responses
    /// - Displaying user-readable text from encoded URLs
    ///
    /// - Returns: The decoded string, or the original string if decoding fails
    ///
    /// - Note: This is a safe wrapper around `removingPercentEncoding`
    ///         that prevents nil by returning the original on failure
    var urlUnescaped: String {
        self.removingPercentEncoding ?? self
    }
    
    // MARK: - Query Parameter Parsing
    
    /// Parses the string as a URL query string and returns key-value pairs.
    ///
    /// This property treats the string as a URL query string (format: `key=value&key2=value2`)
    /// and extracts all parameters into a dictionary. Useful for parsing OAuth callback
    /// parameters, form data, or any query-string-formatted data.
    ///
    /// **Parsing Features:**
    /// - Automatically decodes percent-encoded values
    /// - Handles parameters without values (treated as empty strings)
    /// - Supports both `&` and `;` as separators (URL standard)
    /// - Returns empty dictionary for malformed strings
    ///
    /// **Example Usage:**
    /// ```swift
    /// // Basic query string
    /// let query1 = "code=abc123&state=xyz&expires_in=3600"
    /// let params1 = query1.urlQueryParameters
    /// print(params1["code"])        // "abc123"
    /// print(params1["expires_in"])  // "3600"
    ///
    /// // Percent-encoded values (automatically decoded)
    /// let query2 = "name=John%20Doe&email=john%40example.com"
    /// let params2 = query2.urlQueryParameters
    /// print(params2["name"])   // "John Doe"
    /// print(params2["email"])  // "john@example.com"
    ///
    /// // OAuth error response
    /// let error = "error=access_denied&error_description=User%20cancelled%20login"
    /// let params3 = error.urlQueryParameters
    /// print(params3["error_description"])  // "User cancelled login"
    ///
    /// // Parameters without values
    /// let query4 = "key1=value1&key2&key3="
    /// let params4 = query4.urlQueryParameters
    /// print(params4["key2"])  // "" (empty string)
    /// print(params4["key3"])  // "" (empty string)
    ///
    /// // Duplicate keys (last value wins)
    /// let query5 = "key=first&key=second"
    /// let params5 = query5.urlQueryParameters
    /// print(params5["key"])  // "second"
    /// ```
    ///
    /// **OAuth Callback Parsing:**
    /// ```swift
    /// // Extract parameters from callback URL's query string
    /// let callbackURL = URL(string: "myapp://callback?code=abc&state=xyz")!
    /// if let query = callbackURL.query {
    ///     let params = query.urlQueryParameters
    ///     let code = params["code"]
    ///     // Exchange code for token
    /// }
    /// ```
    ///
    /// **Implementation Note:**
    ///
    /// This property uses `URLComponents` for parsing, which provides robust
    /// handling of edge cases and proper percent-decoding. A dummy URL
    /// (`https://dummy.com`) is temporarily constructed to leverage URLComponents'
    /// query parsing capabilities.
    ///
    /// - Returns: A dictionary of parameter names to values (both strings)
    ///
    /// - Note: Returns an empty dictionary if the string cannot be parsed as a query string
    ///
    /// - Complexity: O(n) where n is the number of parameters
    var urlQueryParameters: [String: String] {
        // We add a dummy scheme and host to use the powerful URLComponents parser.
        // URLComponents requires a complete URL structure to parse properly.
        let urlString = "https://dummy.com?\(self)"
        
        guard let components = URLComponents(string: urlString) else {
            return [:]
        }
        
        // The `queryItems` property automatically handles percent-decoding
        // and provides a clean array of name-value pairs.
        return components.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        } ?? [:]
    }
}

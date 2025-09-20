import Foundation

// MARK: - String Extensions
public extension String {
    
    /// Returns a new string with characters escaped for safe use in JavaScript string literals.
    var javascriptEscaped: String {
        var escaped = self
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
        escaped = escaped.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
        escaped = escaped.replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return escaped
    }
    
    /// Returns a new string that has been percent-encoded for safe use in URLs,
    /// specifically following the strict requirements of RFC 3986 for OAuth 1.0a signatures.
    var urlEscaped: String {
        // The "unreserved" character set is defined in RFC 3986 Section 2.3.
        let unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        let allowed = CharacterSet(charactersIn: unreserved)
        return self.addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
    
    /// A convenience property that safely removes percent-encoding from the string.
    var urlUnescaped: String {
        self.removingPercentEncoding ?? self
    }

    /// Parses the string as a URL query string (e.g., "key=value&key2=value2")
    /// and returns its key-value pairs in a dictionary.
    var urlQueryParameters: [String: String] {
        // We add a dummy scheme and host to use the powerful URLComponents parser.
        let urlString = "https://dummy.com?\(self)"
        guard let components = URLComponents(string: urlString) else {
            return [:]
        }
        
        // The `queryItems` property automatically handles decoding.
        return components.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        } ?? [:]
    }
}

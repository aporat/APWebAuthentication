import Foundation

// MARK: - URL Extension for Web Authentication
public extension URL {
    
    /// The base URL string for OAuth signature generation, as per RFC 5849.
    /// This string excludes the query, fragment, user, password, and default ports.
    var oAuthBaseURL: String? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.query = nil
        components.fragment = nil
        components.user = nil
        components.password = nil
        
        // URLComponents automatically omits default ports (80 for http, 443 for https)
        // when generating the string, simplifying the logic.
        return components.string
    }

    /// Checks if the URL scheme is either `http` or `https`.
    func isWebURL() -> Bool {
        guard let scheme = self.scheme?.lowercased() else {
            return false
        }
        return ["http", "https"].contains(scheme)
    }
    
    /// Returns a new URL without the scheme component.
    var withoutScheme: URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = nil
        return components?.url
    }

    /// A dictionary of parameters from the URL's query string and/or fragment.
    /// If a key exists in both, the value from the fragment takes precedence.
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

    /// Parses the URL to determine if it represents a success or failure response.
    func getResponse() -> Result<[String: String], APWebAuthenticationError> {
        let params = self.parameters

        // Check for various error keys used in OAuth and other APIs.
        let errorReason = params["error_description"] ?? params["error_message"] ?? params["error"]
        
        if let reason = errorReason?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding {
            if params["error_type"] == "login_failed" {
                return .failure(.loginFailed(reason: reason))
            }
            return .failure(.failed(reason: reason))
        }

        return .success(params)
    }
}

import Foundation

// MARK: - Web Authentication Link

/// Represents a link from HTTP Link headers (RFC 5988) or HTML link elements.
///
/// `APWebAuthenticationLink` parses and represents web links with their parameters,
/// commonly used for:
/// - API pagination (next, prev, first, last links)
/// - Resource discovery (alternate, canonical links)
/// - Relationship indication (author, license links)
/// - Preloading and prefetching hints
///
/// **RFC 5988 Format:**
/// ```
/// Link: <https://api.example.com/users?page=3>; rel="next",
///       <https://api.example.com/users?page=1>; rel="prev"
/// ```
///
/// **Example Usage:**
/// ```swift
/// // Parse from HTTP header
/// let header = response.allHeaderFields["Link"] as? String
/// let links = parseLinkHeader(header)
///
/// // Find specific link
/// if let nextLink = response.findLink(for: "next") {
///     print("Next page: \(nextLink.uri)")
/// }
///
/// // Create programmatically
/// let link = APWebAuthenticationLink(
///     uri: "https://api.example.com/users?page=2",
///     parameters: ["rel": "next", "type": "application/json"]
/// )
/// ```
///
/// - Note: Conforms to `Equatable`, `Hashable`, and `Sendable` for safe use across threads.
public struct APWebAuthenticationLink: Equatable, Hashable, Sendable {

    // MARK: - Properties

    /// The URI for the link.
    ///
    /// This can be an absolute or relative URL. When parsed from HTTP headers,
    /// relative URLs are resolved against the response's base URL.
    ///
    /// **Example:**
    /// ```swift
    /// link.uri // "https://api.example.com/users?page=3"
    /// ```
    public let uri: String

    /// The parameters for the link.
    ///
    /// Common parameters include:
    /// - `rel` - Relationship type (next, prev, canonical, etc.)
    /// - `type` - Media type hint (application/json, text/html, etc.)
    /// - `title` - Human-readable title
    /// - `hreflang` - Language of the linked resource
    ///
    /// **Example:**
    /// ```swift
    /// link.parameters["rel"] // "next"
    /// link.parameters["type"] // "application/json"
    /// ```
    public let parameters: [String: String]

    // MARK: - Initialization

    /// Initializes a link with a given URI and parameters.
    ///
    /// **Example:**
    /// ```swift
    /// let link = APWebAuthenticationLink(
    ///     uri: "/users?page=2",
    ///     parameters: ["rel": "next"]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - uri: The link URI (absolute or relative)
    ///   - parameters: Optional link parameters (rel, type, etc.)
    public init(uri: String, parameters: [String: String]? = nil) {
        self.uri = uri
        self.parameters = parameters ?? [:]
    }

    // MARK: - Hashable Conformance

    /// Hashes the link based on its URI and parameters.
    ///
    /// - Parameter hasher: The hasher to combine values into
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uri)
        hasher.combine(parameters)
    }

    /// Compares two links for equality.
    ///
    /// Two links are equal if they have the same URI and parameters.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side link
    ///   - rhs: The right-hand side link
    ///
    /// - Returns: `true` if both links are equal, `false` otherwise
    public static func == (lhs: APWebAuthenticationLink, rhs: APWebAuthenticationLink) -> Bool {
        lhs.uri == rhs.uri && lhs.parameters == rhs.parameters
    }

    // MARK: - Common Parameters

    /// The relation type of the link (e.g., "next", "prev", "canonical").
    ///
    /// This is the most important parameter, indicating the relationship between
    /// the current resource and the linked resource.
    ///
    /// **Common Values:**
    /// - `next` - Next page in a sequence
    /// - `prev` - Previous page in a sequence
    /// - `first` - First page
    /// - `last` - Last page
    /// - `canonical` - Canonical/preferred version
    /// - `alternate` - Alternative representation
    ///
    /// **Example:**
    /// ```swift
    /// if link.relationType == "next" {
    ///     loadNextPage(link.uri)
    /// }
    /// ```
    ///
    /// - Returns: The relation type, or `nil` if not specified
    public var relationType: String? {
        parameters["rel"]
    }

    /// The reverse relation of the link.
    ///
    /// Indicates the reverse relationship from the linked resource back to
    /// the current resource. Less commonly used than `rel`.
    ///
    /// **Example:**
    /// ```swift
    /// if link.reverseRelationType == "author" {
    ///     // The linked resource has this page as its author
    /// }
    /// ```
    ///
    /// - Returns: The reverse relation type, or `nil` if not specified
    public var reverseRelationType: String? {
        parameters["rev"]
    }

    /// A hint of what the content type for the link may be.
    ///
    /// Indicates the expected media type of the linked resource.
    /// Useful for preloading or determining how to handle the link.
    ///
    /// **Common Values:**
    /// - `application/json`
    /// - `text/html`
    /// - `application/xml`
    /// - `image/png`
    ///
    /// **Example:**
    /// ```swift
    /// if link.type == "application/json" {
    ///     // Expect JSON response
    ///     fetchJSON(from: link.uri)
    /// }
    /// ```
    ///
    /// - Returns: The content type hint, or `nil` if not specified
    public var type: String? {
        parameters["type"]
    }
}

// MARK: - HTML Conversion

extension APWebAuthenticationLink {

    /// Encodes the link into an HTML `<link>` element string.
    ///
    /// Converts the link to an HTML element suitable for inclusion in HTML documents.
    /// All parameters are converted to attributes.
    ///
    /// **Example:**
    /// ```swift
    /// let link = APWebAuthenticationLink(
    ///     uri: "/style.css",
    ///     parameters: ["rel": "stylesheet", "type": "text/css"]
    /// )
    /// print(link.html)
    /// // <link href="/style.css" rel="stylesheet" type="text/css" />
    /// ```
    ///
    /// - Returns: An HTML `<link>` element string
    public var html: String {
        let paramString = parameters.map { key, value in
            "\(key)=\"\(value)\""
        }.joined(separator: " ")

        return "<link href=\"\(uri)\" \(paramString) />"
    }
}

// MARK: - HTTP Header Conversion

extension APWebAuthenticationLink {

    /// Encodes the link into a `Link` header string, as per RFC 5988.
    ///
    /// Converts the link to the format used in HTTP Link headers.
    /// The URI is wrapped in angle brackets, followed by parameters
    /// as semicolon-separated key="value" pairs.
    ///
    /// **Example:**
    /// ```swift
    /// let link = APWebAuthenticationLink(
    ///     uri: "https://api.example.com/users?page=2",
    ///     parameters: ["rel": "next"]
    /// )
    /// print(link.header)
    /// // <https://api.example.com/users?page=2>; rel="next"
    /// ```
    ///
    /// - Returns: An RFC 5988 Link header value string
    public var header: String {
        let paramString = parameters.map { key, value in
            "; \(key)=\"\(value)\""
        }.joined()

        return "<\(uri)>\(paramString)"
    }

    /// Initializes a link by parsing a single HTTP `Link` header value.
    ///
    /// Parses an RFC 5988 Link header component, extracting the URI and
    /// all associated parameters.
    ///
    /// **Format:**
    /// ```
    /// <https://api.example.com/users?page=3>; rel="next"; type="application/json"
    /// ```
    ///
    /// **Example:**
    /// ```swift
    /// let header = "<https://api.example.com/users?page=2>; rel=\"next\""
    /// if let link = APWebAuthenticationLink(header: header) {
    ///     print(link.uri) // "https://api.example.com/users?page=2"
    ///     print(link.relationType) // "next"
    /// }
    /// ```
    ///
    /// - Parameter header: A string component from a `Link` header
    /// - Returns: The parsed link, or `nil` if the format is invalid
    public init?(header: String) {
        let components = header.components(separatedBy: ";").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        guard !components.isEmpty else { return nil }

        // Extract and clean the URI (must be in angle brackets)
        let uriComponent = components[0]
        guard uriComponent.hasPrefix("<") && uriComponent.hasSuffix(">") else {
            return nil
        }
        self.uri = String(uriComponent.dropFirst().dropLast())

        // Parse parameters (key=value pairs)
        var params: [String: String] = [:]
        for paramComponent in components.dropFirst() {
            let paramParts = paramComponent.split(separator: "=", maxSplits: 1).map(String.init)
            if paramParts.count == 2 {
                let key = paramParts[0]
                let value = paramParts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                params[key] = value
            }
        }
        self.parameters = params
    }
}

// MARK: - Link Header Parsing

/// Parses a Web Linking (RFC 5988) header into an array of links.
///
/// HTTP Link headers can contain multiple links separated by commas.
/// This function parses the complete header and returns all valid links.
///
/// **Example:**
/// ```swift
/// let header = """
/// </page=3>; rel="next", </page=1>; rel="prev", </page=1>; rel="first"
/// """
/// let links = parseLinkHeader(header)
///
/// for link in links {
///     print("\(link.relationType ?? "unknown"): \(link.uri)")
/// }
/// // Output:
/// // next: /page=3
/// // prev: /page=1
/// // first: /page=1
/// ```
///
/// - Parameter header: Full RFC 5988 link header string
/// - Returns: An array of `APWebAuthenticationLink` structs
public func parseLinkHeader(_ header: String) -> [APWebAuthenticationLink] {
    header.components(separatedBy: ",").compactMap { APWebAuthenticationLink(header: $0) }
}

// MARK: - HTTPURLResponse Extension

extension HTTPURLResponse {

    /// Parses links from the response's `Link` header.
    ///
    /// Automatically extracts and parses the Link header from the HTTP response.
    /// Relative URIs are resolved against the response's base URL.
    ///
    /// **Example:**
    /// ```swift
    /// let response = // ... HTTPURLResponse
    /// for link in response.links {
    ///     if link.relationType == "next" {
    ///         print("Next page: \(link.uri)")
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: An array of links from the Link header, or empty array if none exist
    public var links: [APWebAuthenticationLink] {
        guard let linkHeader = allHeaderFields["Link"] as? String else {
            return []
        }

        return parseLinkHeader(linkHeader).map { link in
            // Handle relative URIs by resolving them against the response's base URL
            if let baseURL = self.url, let resolvedURL = URL(string: link.uri, relativeTo: baseURL) {
                return APWebAuthenticationLink(uri: resolvedURL.absoluteString, parameters: link.parameters)
            }
            return link
        }
    }

    /// Finds a link that has a set of matching parameters.
    ///
    /// Searches through the response's links for one that contains all the
    /// specified parameter key-value pairs.
    ///
    /// **Example:**
    /// ```swift
    /// // Find link with rel="next" and type="application/json"
    /// let link = response.findLink(where: [
    ///     "rel": "next",
    ///     "type": "application/json"
    /// ])
    /// ```
    ///
    /// - Parameter parameters: A dictionary of parameters to match
    /// - Returns: The first matching link, or `nil` if none match
    public func findLink(where parameters: [String: String]) -> APWebAuthenticationLink? {
        links.first { link in
            parameters.allSatisfy { key, value in
                link.parameters[key] == value
            }
        }
    }

    /// Finds a link for a specific relation type.
    ///
    /// This is a convenience method that searches for a link with a specific
    /// `rel` parameter value.
    ///
    /// **Example:**
    /// ```swift
    /// // Find next page link
    /// if let nextLink = response.findLink(for: "next") {
    ///     loadPage(url: nextLink.uri)
    /// }
    ///
    /// // Find canonical link
    /// if let canonicalLink = response.findLink(for: "canonical") {
    ///     print("Canonical URL: \(canonicalLink.uri)")
    /// }
    /// ```
    ///
    /// - Parameter relation: The relation type to find (e.g., "next", "prev")
    /// - Returns: The first link with the specified relation, or `nil` if none found
    public func findLink(for relation: String) -> APWebAuthenticationLink? {
        findLink(where: ["rel": relation])
    }
}

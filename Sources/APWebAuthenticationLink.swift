import Foundation

// MARK: - Web Authentication Link

/// Represents a link from HTTP Link headers (RFC 5988) or HTML link elements.
///
/// Used for API pagination, resource discovery, and relationship indication.
///
/// **Example Usage:**
/// ```swift
/// // Parse from HTTP header
/// let links = parseLinkHeader(response.allHeaderFields["Link"] as? String)
///
/// // Find specific link
/// if let nextLink = response.findLink(for: "next") {
///     print("Next page: \(nextLink.uri)")
/// }
/// ```
public struct APWebAuthenticationLink: Equatable, Hashable, Sendable {

    // MARK: - Properties

    /// The URI for the link (absolute or relative).
    public let uri: String

    /// The parameters for the link (rel, type, title, etc.).
    public let parameters: [String: String]

    // MARK: - Initialization

    /// Initializes a link with a given URI and parameters.
    ///
    /// - Parameters:
    ///   - uri: The link URI
    ///   - parameters: Optional link parameters
    public init(uri: String, parameters: [String: String]? = nil) {
        self.uri = uri
        self.parameters = parameters ?? [:]
    }

    // MARK: - Hashable Conformance

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uri)
        hasher.combine(parameters)
    }

    public static func == (lhs: APWebAuthenticationLink, rhs: APWebAuthenticationLink) -> Bool {
        lhs.uri == rhs.uri && lhs.parameters == rhs.parameters
    }

    // MARK: - Common Parameters

    /// The relation type of the link (e.g., "next", "prev", "canonical").
    public var relationType: String? {
        parameters["rel"]
    }

    /// The reverse relation of the link.
    public var reverseRelationType: String? {
        parameters["rev"]
    }

    /// A hint of what the content type for the link may be.
    public var type: String? {
        parameters["type"]
    }
}

// MARK: - HTML Conversion

extension APWebAuthenticationLink {

    /// Encodes the link into an HTML `<link>` element string.
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
    /// **Example:**
    /// ```swift
    /// let link = APWebAuthenticationLink(
    ///     uri: "https://api.example.com/users?page=2",
    ///     parameters: ["rel": "next"]
    /// )
    /// print(link.header)
    /// // <https://api.example.com/users?page=2>; rel="next"
    /// ```
    public var header: String {
        let paramString = parameters.map { key, value in
            "; \(key)=\"\(value)\""
        }.joined()

        return "<\(uri)>\(paramString)"
    }

    /// Initializes a link by parsing a single HTTP `Link` header value.
    ///
    /// **Format:** `<https://api.example.com/users?page=3>; rel="next"; type="application/json"`
    ///
    /// - Parameter header: A string component from a `Link` header
    /// - Returns: The parsed link, or nil if the format is invalid
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
/// **Example:**
/// ```swift
/// let header = "</page=3>; rel=\"next\", </page=1>; rel=\"prev\""
/// let links = parseLinkHeader(header)
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
    /// Relative URIs are resolved against the response's base URL.
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
    /// - Parameter parameters: A dictionary of parameters to match
    /// - Returns: The first matching link, or nil if none match
    public func findLink(where parameters: [String: String]) -> APWebAuthenticationLink? {
        links.first { link in
            parameters.allSatisfy { key, value in
                link.parameters[key] == value
            }
        }
    }

    /// Finds a link for a specific relation type.
    ///
    /// **Example:**
    /// ```swift
    /// if let nextLink = response.findLink(for: "next") {
    ///     loadPage(url: nextLink.uri)
    /// }
    /// ```
    ///
    /// - Parameter relation: The relation type to find (e.g., "next", "prev")
    /// - Returns: The first link with the specified relation, or nil if none found
    public func findLink(for relation: String) -> APWebAuthenticationLink? {
        findLink(where: ["rel": relation])
    }
}

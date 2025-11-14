import Foundation

public struct APWebAuthenticationLink: Equatable, Hashable, Sendable {
    /// The URI for the link.
    public let uri: String

    /// The parameters for the link.
    public let parameters: [String: String]

    /// Initializes a Link with a given URI and parameters.
    public init(uri: String, parameters: [String: String]? = nil) {
        self.uri = uri
        self.parameters = parameters ?? [:]
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uri)
        hasher.combine(parameters)
    }

    public static func == (lhs: APWebAuthenticationLink, rhs: APWebAuthenticationLink) -> Bool {
        lhs.uri == rhs.uri && lhs.parameters == rhs.parameters
    }

    /// Relation type of the Link (e.g., "next", "prev").
    public var relationType: String? {
        parameters["rel"]
    }

    /// Reverse relation of the Link.
    public var reverseRelationType: String? {
        parameters["rev"]
    }

    /// A hint of what the content type for the link may be.
    public var type: String? {
        parameters["type"]
    }
}

// MARK: - HTML Element Conversion
extension APWebAuthenticationLink {
    /// Encodes the link into an HTML `<link>` element string.
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
    public var header: String {
        let paramString = parameters.map { key, value in
            "; \(key)=\"\(value)\""
        }.joined()
        
        return "<\(uri)>\(paramString)"
    }

    /// Initializes a Link by parsing a single HTTP `Link` header value.
    /// - parameter header: A string component from a `Link` header (e.g., `<http://example.com>; rel="next"`).
    public init?(header: String) {
        let components = header.components(separatedBy: ";").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        guard !components.isEmpty else { return nil }

        // Extract and clean the URI
        let uriComponent = components[0]
        guard uriComponent.hasPrefix("<") && uriComponent.hasSuffix(">") else {
            return nil
        }
        self.uri = String(uriComponent.dropFirst().dropLast())

        // Parse parameters
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

/// Parses a Web Linking (RFC 5988) header into an array of Links.
/// - parameter header: Full RFC 5988 link header string. (e.g., `</page=3>; rel="next", </page=1>; rel="prev"`)
/// - returns: An array of `APWebAuthenticationLink` structs.
public func parseLinkHeader(_ header: String) -> [APWebAuthenticationLink] {
    header.components(separatedBy: ",").compactMap { APWebAuthenticationLink(header: $0) }
}

// MARK: - HTTPURLResponse Extension
extension HTTPURLResponse {
    /// Parses the links from the response's `Link` header.
    public var links: [APWebAuthenticationLink] {
        guard let linkHeader = allHeaderFields["Link"] as? String else {
            return []
        }
        
        return parseLinkHeader(linkHeader).map { link in
            // Handle relative URIs by resolving them against the response's base URL.
            if let baseURL = self.url, let resolvedURL = URL(string: link.uri, relativeTo: baseURL) {
                return APWebAuthenticationLink(uri: resolvedURL.absoluteString, parameters: link.parameters)
            }
            return link
        }
    }

    /// Finds a link that has a set of matching parameters.
    /// - parameter parameters: A dictionary of parameters to match (e.g., `["rel": "next"]`).
    public func findLink(where parameters: [String: String]) -> APWebAuthenticationLink? {
        links.first { link in
            parameters.allSatisfy { key, value in
                link.parameters[key] == value
            }
        }
    }

    /// Finds a link for a specific relation type.
    /// - parameter relation: The relation type to find (e.g., "next").
    public func findLink(for relation: String) -> APWebAuthenticationLink? {
        findLink(where: ["rel": relation])
    }
}

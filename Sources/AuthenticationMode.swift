import Foundation

/// Authentication modes for different API access patterns.
///
/// Defines how authentication is performed and what type of access is granted.
///
/// **Example Usage:**
/// ```swift
/// let provider = InstagramProvider(mode: .private)
///
/// // Or from string
/// if let mode = AuthenticationMode("web") {
///     let provider = InstagramProvider(mode: mode)
/// }
/// ```
public enum AuthenticationMode: String, Sendable, CaseIterable {

    /// Private API mode with full native app access.
    case `private`

    /// Explicit OAuth 2.0 authorization flow.
    case explicit

    /// Implicit OAuth 2.0 flow for client-side apps.
    case implicit

    /// Web-based authentication using cookies and sessions.
    case web

    /// Bloks framework authentication (Facebook's UI framework).
    case bloks

    /// Browser-based OAuth flow.
    case browser

    /// Native mobile app authentication.
    case app

    // MARK: - Initialization

    /// Creates an `AuthenticationMode` from an optional string.
    ///
    /// - Parameter string: An optional raw value string
    /// - Returns: The corresponding mode, or nil if invalid
    public init?(_ string: String?) {
        guard let rawValue = string else {
            return nil
        }

        self.init(rawValue: rawValue)
    }

    // MARK: - Computed Properties

    /// Whether this mode uses OAuth 2.0 authentication.
    public var isOAuth: Bool {
        switch self {
        case .explicit, .implicit, .browser:
            return true
        case .private, .web, .bloks, .app:
            return false
        }
    }

    /// Whether this mode uses web-based authentication.
    public var isWebBased: Bool {
        switch self {
        case .web, .browser:
            return true
        case .private, .explicit, .implicit, .bloks, .app:
            return false
        }
    }

    /// Whether this mode uses native app authentication.
    public var isNativeApp: Bool {
        switch self {
        case .private, .app, .bloks:
            return true
        case .explicit, .implicit, .web, .browser:
            return false
        }
    }

    /// Whether this mode supports token refresh.
    public var supportsRefresh: Bool {
        switch self {
        case .explicit, .private, .app:
            return true
        case .implicit, .web, .bloks, .browser:
            return false
        }
    }

    /// A user-friendly description of the mode.
    public var description: String {
        switch self {
        case .private:
            return "Private API"
        case .explicit:
            return "OAuth 2.0 (Explicit)"
        case .implicit:
            return "OAuth 2.0 (Implicit)"
        case .web:
            return "Web Authentication"
        case .bloks:
            return "Bloks Framework"
        case .browser:
            return "Browser OAuth"
        case .app:
            return "Native App"
        }
    }
}

// MARK: - CustomStringConvertible

extension AuthenticationMode: CustomStringConvertible {}

// MARK: - CustomDebugStringConvertible

extension AuthenticationMode: CustomDebugStringConvertible {

    /// Detailed debug description showing the mode and its characteristics.
    public var debugDescription: String {
        var traits: [String] = []

        if isOAuth {
            traits.append("OAuth")
        }
        if isWebBased {
            traits.append("web-based")
        }
        if isNativeApp {
            traits.append("native")
        }
        if supportsRefresh {
            traits.append("refresh")
        }

        let traitsString = traits.isEmpty ? "none" : traits.joined(separator: ", ")
        return "AuthenticationMode.\(rawValue)(traits: [\(traitsString)])"
    }
}

import Foundation

/// Authentication modes for different API access patterns.
///
/// `AuthenticationMode` defines how authentication is performed and what type
/// of access is granted. Different modes provide different levels of access
/// and use different authentication mechanisms.
///
/// **Mode Categories:**
///
/// **API Access Modes:**
/// - **private**: Full private API access with native app authentication
/// - **explicit**: Explicit OAuth flow with full permissions
/// - **implicit**: Implicit OAuth flow (limited permissions)
///
/// **Web Access Modes:**
/// - **web**: Web-based authentication (cookies/session)
/// - **browser**: Browser-based authentication flow
///
/// **App-Specific Modes:**
/// - **bloks**: Bloks (Facebook's UI framework) authentication
/// - **app**: Native mobile app authentication
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
///
/// - Note: Different modes may have different rate limits and available endpoints.
public enum AuthenticationMode: String, Sendable, CaseIterable {

    /// Private API mode with full native app access.
    ///
    /// Uses Instagram's private mobile API endpoints with native app authentication.
    /// Provides access to features not available through public APIs.
    ///
    /// **Characteristics:**
    /// - Full API access
    /// - Native app authentication tokens
    /// - May require app signature verification
    /// - Higher rate limits
    case `private`

    /// Explicit OAuth 2.0 authorization flow.
    ///
    /// Uses standard OAuth 2.0 authorization code flow with user consent screen.
    /// Provides full access to authorized resources.
    ///
    /// **Characteristics:**
    /// - User consent required
    /// - Refresh token support
    /// - Scoped permissions
    /// - Standard OAuth 2.0 flow
    case explicit

    /// Implicit OAuth 2.0 flow for client-side apps.
    ///
    /// Uses OAuth 2.0 implicit flow without server-side token exchange.
    /// Suitable for single-page apps and mobile apps without backend.
    ///
    /// **Characteristics:**
    /// - No refresh token
    /// - Shorter token lifetime
    /// - Limited permissions
    /// - Client-side only
    case implicit

    /// Web-based authentication using cookies and sessions.
    ///
    /// Uses traditional web authentication with cookie-based sessions.
    /// Suitable for browser-based access.
    ///
    /// **Characteristics:**
    /// - Cookie-based sessions
    /// - CSRF token management
    /// - Web-optimized endpoints
    /// - Browser compatibility
    case web

    /// Bloks framework authentication.
    ///
    /// Uses Facebook's Bloks UI framework for authentication flows.
    /// Provides dynamic UI rendering capabilities.
    ///
    /// **Characteristics:**
    /// - Dynamic UI rendering
    /// - Server-driven screens
    /// - Facebook infrastructure
    /// - Modern authentication flows
    case bloks

    /// Browser-based OAuth flow.
    ///
    /// Redirects to browser for authentication, then returns to app.
    /// Standard approach for mobile app OAuth.
    ///
    /// **Characteristics:**
    /// - External browser
    /// - Deep linking
    /// - System authentication
    /// - Secure token handling
    case browser

    /// Native mobile app authentication.
    ///
    /// Uses platform-native authentication mechanisms.
    /// Optimized for mobile app experience.
    ///
    /// **Characteristics:**
    /// - Native UI
    /// - App-specific tokens
    /// - Device binding
    /// - Biometric support (optional)
    case app

    // MARK: - Initialization

    /// Creates an `AuthenticationMode` from an optional string.
    ///
    /// This convenience initializer safely handles nil values and invalid strings.
    ///
    /// **Example:**
    /// ```swift
    /// let mode1 = AuthenticationMode("private") // .private
    /// let mode2 = AuthenticationMode("invalid") // nil
    /// let mode3 = AuthenticationMode(nil) // nil
    /// ```
    ///
    /// - Parameter string: An optional raw value string
    /// - Returns: The corresponding mode, or `nil` if the string is nil or invalid
    public init?(_ string: String?) {
        guard let rawValue = string else {
            return nil
        }

        self.init(rawValue: rawValue)
    }

    // MARK: - Computed Properties

    /// Whether this mode uses OAuth 2.0 authentication.
    ///
    /// Returns `true` for explicit, implicit, and browser modes.
    ///
    /// **Example:**
    /// ```swift
    /// AuthenticationMode.explicit.isOAuth // true
    /// AuthenticationMode.private.isOAuth // false
    /// ```
    public var isOAuth: Bool {
        switch self {
        case .explicit, .implicit, .browser:
            return true
        case .private, .web, .bloks, .app:
            return false
        }
    }

    /// Whether this mode uses web-based authentication.
    ///
    /// Returns `true` for web and browser modes.
    ///
    /// **Example:**
    /// ```swift
    /// AuthenticationMode.web.isWebBased // true
    /// AuthenticationMode.app.isWebBased // false
    /// ```
    public var isWebBased: Bool {
        switch self {
        case .web, .browser:
            return true
        case .private, .explicit, .implicit, .bloks, .app:
            return false
        }
    }

    /// Whether this mode uses native app authentication.
    ///
    /// Returns `true` for private, app, and bloks modes.
    ///
    /// **Example:**
    /// ```swift
    /// AuthenticationMode.app.isNativeApp // true
    /// AuthenticationMode.web.isNativeApp // false
    /// ```
    public var isNativeApp: Bool {
        switch self {
        case .private, .app, .bloks:
            return true
        case .explicit, .implicit, .web, .browser:
            return false
        }
    }

    /// Whether this mode supports token refresh.
    ///
    /// Returns `true` for modes that typically provide refresh tokens.
    ///
    /// **Example:**
    /// ```swift
    /// AuthenticationMode.explicit.supportsRefresh // true
    /// AuthenticationMode.implicit.supportsRefresh // false
    /// ```
    public var supportsRefresh: Bool {
        switch self {
        case .explicit, .private, .app:
            return true
        case .implicit, .web, .bloks, .browser:
            return false
        }
    }

    /// A user-friendly description of the mode.
    ///
    /// **Example:**
    /// ```swift
    /// AuthenticationMode.private.description // "Private API"
    /// AuthenticationMode.explicit.description // "OAuth 2.0 (Explicit)"
    /// ```
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

extension AuthenticationMode: CustomStringConvertible {
    // Uses the computed description property defined above
}

// MARK: - CustomDebugStringConvertible

extension AuthenticationMode: CustomDebugStringConvertible {

    /// Detailed debug description showing the mode and its characteristics.
    ///
    /// **Example:**
    /// ```
    /// AuthenticationMode.explicit(isOAuth: true, supportsRefresh: true)
    /// ```
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

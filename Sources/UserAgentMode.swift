import Foundation

/// User agent modes for customizing browser and device identification.
///
/// Allows clients to mimic different browsers and devices in HTTP requests.
///
/// **Example Usage:**
/// ```swift
/// let auth = InstagramAuthentication()
/// auth.setBrowserMode(.desktop)
///
/// // Or from string
/// if let mode = UserAgentMode("ios-chrome") {
///     auth.setBrowserMode(mode)
/// }
/// ```
public enum UserAgentMode: String, Codable, Sendable, CaseIterable {

    /// System default user agent (typically Safari on iOS).
    case `default`

    /// iOS WebView user agent.
    case webView = "webview"

    /// Generic iOS Safari user agent.
    case ios

    /// Chrome on iOS user agent.
    case iosChrome = "ios-chrome"

    /// iPhone-specific Safari user agent.
    case iphone

    /// Android browser user agent.
    case android

    /// Desktop Safari/Chrome user agent.
    case desktop

    /// Desktop Firefox user agent.
    case desktopFirefox = "desktop-firefox"

    // MARK: - Initialization

    /// Creates a `UserAgentMode` from an optional string.
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

    /// Whether this mode represents a mobile user agent.
    public var isMobile: Bool {
        switch self {
        case .default, .webView, .ios, .iosChrome, .iphone, .android:
            return true
        case .desktop, .desktopFirefox:
            return false
        }
    }

    /// Whether this mode represents a desktop user agent.
    public var isDesktop: Bool {
        switch self {
        case .desktop, .desktopFirefox:
            return true
        case .default, .webView, .ios, .iosChrome, .iphone, .android:
            return false
        }
    }

    /// A user-friendly description of the mode.
    public var description: String {
        switch self {
        case .default:
            return "Default"
        case .webView:
            return "iOS WebView"
        case .ios:
            return "iOS Safari"
        case .iosChrome:
            return "Chrome on iOS"
        case .iphone:
            return "iPhone Safari"
        case .android:
            return "Android Browser"
        case .desktop:
            return "Desktop Browser"
        case .desktopFirefox:
            return "Firefox Desktop"
        }
    }
}

// MARK: - CustomStringConvertible

extension UserAgentMode: CustomStringConvertible {}

// MARK: - CustomDebugStringConvertible

extension UserAgentMode: CustomDebugStringConvertible {

    /// Detailed debug description showing the mode and its properties.
    public var debugDescription: String {
        let type = isMobile ? "mobile" : "desktop"
        return "UserAgentMode.\(rawValue)(type: \(type), description: \"\(description)\")"
    }
}

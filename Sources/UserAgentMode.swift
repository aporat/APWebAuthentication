import Foundation

/// User agent modes for customizing browser and device identification.
///
/// `UserAgentMode` allows clients to mimic different browsers and devices when
/// making HTTP requests. This is useful for:
/// - Testing mobile vs desktop experiences
/// - Bypassing user agent-based restrictions
/// - Matching specific browser behaviors
/// - Emulating native app requests
///
/// **User Agent String Examples:**
/// - **default**: System default (typically Safari on iOS)
/// - **webView**: iOS WebView user agent
/// - **ios**: Generic iOS Safari user agent
/// - **iosChrome**: Chrome on iOS user agent
/// - **iphone**: iPhone-specific Safari user agent
/// - **android**: Android browser user agent
/// - **desktop**: Desktop Safari/Chrome user agent
/// - **desktopFirefox**: Desktop Firefox user agent
///
/// **Example Usage:**
/// ```swift
/// let auth = InstagramAuthentication()
/// auth.setBrowserMode(.desktop) // Use desktop user agent
///
/// // Or from string
/// if let mode = UserAgentMode("ios-chrome") {
///     auth.setBrowserMode(mode)
/// }
/// ```
///
/// - Note: Some platforms may detect and block non-standard user agents.
public enum UserAgentMode: String, Codable, Sendable, CaseIterable {

    /// System default user agent (typically Safari on iOS).
    ///
    /// Uses the operating system's default user agent string.
    case `default`

    /// iOS WebView user agent.
    ///
    /// Mimics a WKWebView or UIWebView user agent string.
    case webView = "webview"

    /// Generic iOS Safari user agent.
    ///
    /// Uses a standard iOS Safari user agent without specific device details.
    case ios

    /// Chrome on iOS user agent.
    ///
    /// Mimics Google Chrome running on iOS (which actually uses Safari's engine).
    case iosChrome = "ios-chrome"

    /// iPhone-specific Safari user agent.
    ///
    /// Uses an iPhone-specific Safari user agent with device identifiers.
    case iphone

    /// Android browser user agent.
    ///
    /// Mimics an Android device with either Chrome or Android Browser.
    case android

    /// Desktop Safari/Chrome user agent.
    ///
    /// Uses a desktop browser user agent (typically macOS Safari or Chrome).
    case desktop

    /// Desktop Firefox user agent.
    ///
    /// Uses a Mozilla Firefox desktop browser user agent.
    case desktopFirefox = "desktop-firefox"

    // MARK: - Initialization

    /// Creates a `UserAgentMode` from an optional string.
    ///
    /// This convenience initializer safely handles nil values and invalid strings.
    ///
    /// **Example:**
    /// ```swift
    /// let mode1 = UserAgentMode("desktop") // .desktop
    /// let mode2 = UserAgentMode("invalid") // nil
    /// let mode3 = UserAgentMode(nil) // nil
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

    /// Whether this mode represents a mobile user agent.
    ///
    /// Returns `true` for iOS, iPhone, Android, and WebView modes.
    ///
    /// **Example:**
    /// ```swift
    /// UserAgentMode.ios.isMobile // true
    /// UserAgentMode.desktop.isMobile // false
    /// ```
    public var isMobile: Bool {
        switch self {
        case .default, .webView, .ios, .iosChrome, .iphone, .android:
            return true
        case .desktop, .desktopFirefox:
            return false
        }
    }

    /// Whether this mode represents a desktop user agent.
    ///
    /// Returns `true` for desktop and desktop Firefox modes.
    ///
    /// **Example:**
    /// ```swift
    /// UserAgentMode.desktop.isDesktop // true
    /// UserAgentMode.ios.isDesktop // false
    /// ```
    public var isDesktop: Bool {
        switch self {
        case .desktop, .desktopFirefox:
            return true
        case .default, .webView, .ios, .iosChrome, .iphone, .android:
            return false
        }
    }

    /// A user-friendly description of the mode.
    ///
    /// **Example:**
    /// ```swift
    /// UserAgentMode.iosChrome.description // "Chrome on iOS"
    /// UserAgentMode.desktop.description // "Desktop Browser"
    /// ```
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

extension UserAgentMode: CustomStringConvertible {
    // Uses the computed description property defined above
}

// MARK: - CustomDebugStringConvertible

extension UserAgentMode: CustomDebugStringConvertible {

    /// Detailed debug description showing the mode and its properties.
    ///
    /// **Example:**
    /// ```
    /// UserAgentMode.ios(mobile: true, description: "iOS Safari")
    /// ```
    public var debugDescription: String {
        let type = isMobile ? "mobile" : "desktop"
        return "UserAgentMode.\(rawValue)(type: \(type), description: \"\(description)\")"
    }
}

import APUserAgentGenerator
import Foundation
@preconcurrency import SwiftyJSON

/// Base class for authentication management across different OAuth versions.
///
/// Provides common functionality: user agent generation, locale configuration,
/// persistence, and account identification.
///
/// **Example:**
/// ```swift
/// let auth = Auth2Authentication()
/// auth.accountIdentifier = "user@example.com"
/// auth.accessToken = "token"
/// await auth.save()
/// ```
@MainActor
open class Authentication {

    // MARK: - Account Identification

    /// Unique identifier for the authenticated account.
    public var accountIdentifier: String?

    /// The URL where authentication settings are stored on disk.
    ///
    /// Format: `{accountIdentifier}.settings`
    public var authSettingsURL: URL? {
        guard let currentAccountIdentifier = accountIdentifier,
              let documentsURL = FileManager.documentsDirectoryURL else {
            return nil
        }

        let fileName = currentAccountIdentifier + ".settings"
        return documentsURL.appendingPathComponent(fileName)
    }

    // MARK: - User Agent Configuration

    /// The browser mode for user agent generation.
    open var browserMode: UserAgentMode?

    /// Custom user agent string override.
    open var customUserAgent: String?

    /// The generated user agent string for HTTP requests.
    ///
    /// Priority: custom user agent → generated based on browser mode → nil for WebView.
    open var userAgent: String? {
        // Priority 1: Custom user agent
        if let currentUserAgent = customUserAgent, !currentUserAgent.isEmpty {
            return currentUserAgent
        }

        // Priority 2: Generate based on browser mode
        if browserMode == nil || browserMode == .default || browserMode == .ios || browserMode == .iphone {
            return APWebBrowserAgentBuilder.builder().generate()
        } else if browserMode == .iosChrome {
            return APWebBrowserAgentBuilder.builder()
                .withDevice(IOSDevice())
                .withBrowser(ChromeBrowser())
                .generate()
        } else if browserMode == .webView {
            return nil
        } else if browserMode == .android {
            return APWebBrowserAgentBuilder.builder()
                .withDevice(AndroidDevice(deviceModel: "Pixel 7"))
                .withBrowser(ChromeBrowser(version: "123.0.6312.86"))
                .generate()
        } else if browserMode == .desktop {
            return APWebBrowserAgentBuilder.builder()
                .withDevice(MacDevice())
                .withBrowser(ChromeBrowser())
                .generate()
        } else if browserMode == .desktopFirefox {
            return APWebBrowserAgentBuilder.builder()
                .withDevice(MacDevice())
                .withBrowser(FirefoxBrowser())
                .generate()
        }

        return nil
    }

    // MARK: - Locale Configuration

    /// The locale identifier in format `language_REGION` (e.g., "en_US").
    public var localeIdentifier: String {
        if Locale.current.identifier == "en" {
            return "en_US"
        }
        return Locale.current.identifier
    }

    /// The region code from the current locale (e.g., "US", "GB").
    open var localeRegionIdentifier: String {
        if let regionCode = Locale.current.region?.identifier {
            return regionCode
        }
        return "US"
    }

    /// The language code from the current locale (e.g., "en", "es").
    open var localeLanguageCode: String {
        if let languageCode = Locale.current.language.languageCode?.identifier {
            return languageCode
        }
        return "en"
    }

    /// The locale identifier in web format `language-REGION` (e.g., "en-US").
    open var localeWebIdentifier: String {
        localeIdentifier.replacingOccurrences(of: "_", with: "-")
    }

    // MARK: - Initialization

    /// Creates a new authentication instance.
    public required init() {}

    // MARK: - Persistence

    /// Loads credentials and settings from disk.
    ///
    /// Subclasses should override to load specific credentials.
    open func load() async {}

    /// Saves credentials and settings to disk.
    ///
    /// Subclasses should override to save specific credentials.
    open func save() async {}

    /// Deletes credentials and settings from disk.
    ///
    /// Subclasses should call super and clear their properties.
    public func delete() async {
        guard let url = authSettingsURL else {
            return
        }

        try? await Task.detached {
            try FileManager.default.removeItem(at: url)
        }.value
    }

    // MARK: - Configuration

    /// Loads configuration settings from a JSON options object.
    ///
    /// Supported options:
    /// - `browser_mode`: Sets the user agent mode
    /// - `custom_user_agent`: Sets a custom user agent string
    ///
    /// - Parameter options: JSON object containing configuration
    open func configure(with options: JSON?) {
        // Update browser mode
        if let value = UserAgentMode(options?["browser_mode"].string) {
            browserMode = value
        }

        // Update custom user agent
        if let value = options?["custom_user_agent"].string {
            customUserAgent = value
        }
    }
}

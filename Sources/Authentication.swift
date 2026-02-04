import APUserAgentGenerator
import Foundation
@preconcurrency import SwiftyJSON

/// Base class for authentication management across different OAuth versions.
///
/// `Authentication` provides common functionality for all authentication types:
/// - User agent generation and customization
/// - Locale and language configuration
/// - Persistence (disk storage of credentials and settings)
/// - Runtime configuration (from JSON/server)
/// - Account identification
///
/// **Subclassing:**
/// Subclasses (Auth1Authentication, Auth2Authentication) should override:
/// - `load()` - Load persisted credentials and settings from disk
/// - `save()` - Save credentials and settings to disk
/// - `delete()` - Delete credentials and settings (calling super)
/// - `configure(with:)` - Apply runtime configuration from JSON
///
/// **Example:**
/// ```swift
/// let auth = Auth2Authentication()
/// auth.accountIdentifier = "user@example.com"
/// auth.accessToken = "token"
/// await auth.save()
/// ```
///
/// - Note: All operations must be performed on the main actor.
@MainActor
open class Authentication {

    // MARK: - Account Identification

    /// Unique identifier for the authenticated account.
    ///
    /// This is typically the username, email, or user ID that uniquely identifies
    /// the account. It's used to:
    /// - Generate unique file names for storing settings
    /// - Distinguish between multiple accounts
    /// - Track which account is currently active
    ///
    /// **Example:**
    /// ```swift
    /// auth.accountIdentifier = "john_doe"
    /// // Settings will be saved to: john_doe.settings
    /// ```
    public var accountIdentifier: String?

    /// The URL where authentication settings are stored on disk.
    ///
    /// Automatically generated from the `accountIdentifier` and documents directory.
    /// Returns `nil` if no account identifier is set or documents directory is unavailable.
    ///
    /// **File Format:** `{accountIdentifier}.settings`
    ///
    /// **Example:**
    /// ```swift
    /// auth.accountIdentifier = "user123"
    /// print(auth.authSettingsURL)
    /// // ~/Documents/user123.settings
    /// ```
    ///
    /// - Returns: URL to the settings file, or `nil` if it cannot be determined
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
    ///
    /// Determines what browser/device combination to mimic in HTTP requests.
    /// Common values: `.ios`, `.android`, `.desktop`, `.iosChrome`
    ///
    /// - Note: Set to `nil` or `.default` to use the default iOS Safari user agent.
    open var browserMode: UserAgentMode?

    /// Custom user agent string override.
    ///
    /// When set, this overrides automatic user agent generation and uses
    /// the provided string exactly as-is.
    ///
    /// **Example:**
    /// ```swift
    /// auth.customUserAgent = "MyApp/1.0 (iPhone; iOS 17.0)"
    /// ```
    open var customUserAgent: String?

    /// The generated user agent string for HTTP requests.
    ///
    /// Returns the user agent based on priority:
    /// 1. Custom user agent (if set)
    /// 2. Generated user agent based on `browserMode`
    /// 3. `nil` for WebView mode
    ///
    /// **Generated User Agents:**
    /// - `.default`, `.ios`, `.iphone` → iOS Safari
    /// - `.iosChrome` → Chrome on iOS
    /// - `.android` → Chrome on Android
    /// - `.desktop` → Chrome on macOS
    /// - `.desktopFirefox` → Firefox on macOS
    /// - `.webView` → `nil` (uses system WebView agent)
    ///
    /// - Returns: The user agent string, or `nil` for WebView mode
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
    ///
    /// Uses the current device locale, with a fallback to "en_US" for generic "en".
    ///
    /// **Example:**
    /// ```swift
    /// print(auth.localeIdentifier) // "en_US", "es_ES", "fr_FR", etc.
    /// ```
    public var localeIdentifier: String {
        if Locale.current.identifier == "en" {
            return "en_US"
        }
        return Locale.current.identifier
    }

    /// The region code (country) from the current locale (e.g., "US", "GB", "FR").
    ///
    /// Falls back to "US" if the region cannot be determined.
    ///
    /// **Example:**
    /// ```swift
    /// print(auth.localeRegionIdentifier) // "US", "CA", "GB", etc.
    /// ```
    open var localeRegionIdentifier: String {
        if let regionCode = Locale.current.region?.identifier {
            return regionCode
        }
        return "US"
    }

    /// The language code from the current locale (e.g., "en", "es", "fr").
    ///
    /// Falls back to "en" if the language cannot be determined.
    ///
    /// **Example:**
    /// ```swift
    /// print(auth.localeLanguageCode) // "en", "es", "fr", etc.
    /// ```
    open var localeLanguageCode: String {
        if let languageCode = Locale.current.language.languageCode?.identifier {
            return languageCode
        }
        return "en"
    }

    /// The locale identifier in web format `language-REGION` (e.g., "en-US").
    ///
    /// Converts underscores to hyphens for HTTP Accept-Language headers.
    ///
    /// **Example:**
    /// ```swift
    /// print(auth.localeWebIdentifier) // "en-US", "es-ES", "fr-FR", etc.
    /// ```
    open var localeWebIdentifier: String {
        localeIdentifier.replacingOccurrences(of: "_", with: "-")
    }

    // MARK: - Initialization

    /// Creates a new authentication instance with default configuration.
    ///
    /// Subclasses must implement this required initializer.
    public required init() {}

    // MARK: - Persistence

    /// Loads credentials and settings from disk.
    ///
    /// Subclasses should override this method to load their specific credentials and configuration.
    /// The base implementation does nothing.
    ///
    /// **Example Override:**
    /// ```swift
    /// override func load() async {
    ///     guard let url = authSettingsURL else { return }
    ///     let data = try? Data(contentsOf: url)
    ///     // Decode and set credentials...
    /// }
    /// ```
    open func load() async {}

    /// Saves credentials and settings to disk.
    ///
    /// Subclasses should override this method to save their specific credentials and configuration.
    /// The base implementation does nothing.
    ///
    /// **Example Override:**
    /// ```swift
    /// override func save() async {
    ///     guard let url = authSettingsURL else { return }
    ///     let data = try? encode(settings)
    ///     try? data?.write(to: url)
    /// }
    /// ```
    open func save() async {}

    /// Deletes credentials and settings from disk.
    ///
    /// Deletes the settings file from the file system.
    /// Subclasses should call `super.delete()` and then clear their
    /// specific properties (tokens, secrets, etc.).
    ///
    /// **Example Override:**
    /// ```swift
    /// override func delete() async {
    ///     await super.delete()
    ///     accessToken = nil
    ///     refreshToken = nil
    /// }
    /// ```
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
    /// This method updates the authentication configuration based on provided options.
    /// Supported options:
    /// - `browser_mode`: Sets the user agent mode (mobile, desktop, or custom)
    /// - `custom_user_agent`: Sets a custom user agent string
    ///
    /// **Example:**
    /// ```swift
    /// let options: JSON = [
    ///     "browser_mode": "desktop",
    ///     "custom_user_agent": "MyApp/2.0 (iPhone; iOS 17.0)"
    /// ]
    /// await client.loadSettings(options)
    /// ```
    ///
    /// - Parameter options: JSON object containing configuration key-value pairs
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

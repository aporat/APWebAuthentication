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

    /// Legacy on-disk location for settings.
    ///
    /// Credentials are persisted to the Keychain; this URL is no longer read
    /// or written by the library and is retained only for API compatibility.
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

    /// Keychain namespace used to disambiguate credentials between different
    /// authentication types that may share an `accountIdentifier`.
    ///
    /// Subclasses override to provide a stable category (e.g. `"oauth1"`).
    open var keychainCategory: String { "default" }

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

    /// Deletes credentials and settings from the Keychain.
    ///
    /// Subclasses should call super and clear their properties.
    public func delete() async {
        guard let account = accountIdentifier else { return }
        let category = keychainCategory

        await Task.detached {
            try? KeychainStore.delete(account: account, category: category)
        }.value
    }

    // MARK: - Keychain Helpers

    /// Encodes `settings` as a property list and stores it in the Keychain
    /// under `(keychainCategory, accountIdentifier)`.
    ///
    /// No-op if `accountIdentifier` is `nil`.
    func saveSettings<T: Codable & Sendable>(_ settings: T) async {
        guard let account = accountIdentifier else { return }
        let category = keychainCategory

        do {
            let data = try PropertyListEncoder().encode(settings)
            try await Task.detached {
                try KeychainStore.save(data, account: account, category: category)
            }.value
        } catch {
            print("⚠️ Failed to store credentials in keychain: \(error)")
        }
    }

    /// Reads a previously-saved `T` from the Keychain. Returns `nil` if no
    /// value has been stored yet.
    func loadSettings<T: Codable & Sendable>(_ type: T.Type) async -> T? {
        guard let account = accountIdentifier else { return nil }
        let category = keychainCategory

        do {
            let data: Data? = try await Task.detached {
                try KeychainStore.load(account: account, category: category)
            }.value

            guard let data else { return nil }
            return try PropertyListDecoder().decode(T.self, from: data)
        } catch {
            print("⚠️ Failed to load credentials from keychain: \(error)")
            return nil
        }
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

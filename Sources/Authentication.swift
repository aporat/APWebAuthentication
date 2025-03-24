import UIKit

open class Authentication {
    public var accountIdentifier: String?

    public var authSettingsURL: URL? {
        guard let currentAccountIdentifier = accountIdentifier else {
            return nil
        }

        return URL(fileURLWithPath: String.documentDirectory.appendingPathComponent(currentAccountIdentifier + ".settings"))
    }

    // MARK: - User Agent

    open var browserMode: ProviderBrowserMode?
    open var customUserAgent: String?

    var webiPhoneUserAgent: String {
        "Mozilla/5.0 (iPhone; CPU iPhone OS 13_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1 Mobile/15E148 Safari/604.1"
    }

    var webAndroidUserAgent: String {
        "Mozilla/5.0 (Linux; Android 10; Pixel 2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.136 Mobile Safari/537.36"
    }

    var webDesktopFirefoxUserAgent: String {
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:75.0) Gecko/20100101 Firefox/75.0"
    }

    open var userAgent: String? {
        if let currentUserAgent = customUserAgent, !currentUserAgent.isEmpty {
            return currentUserAgent
        } else if browserMode == .default {
            return UserAgentBuilder().build(desktopMode: false)
        } else if browserMode == .ios {
            return UserAgentBuilder().build(desktopMode: false)
        } else if browserMode == .webView {
            return nil
        } else if browserMode == .iphone {
            return webiPhoneUserAgent
        } else if browserMode == .android {
            return webAndroidUserAgent
        } else if browserMode == .desktop {
            return UserAgentBuilder().build(desktopMode: true)
        } else if browserMode == .desktopFirefox {
            return webDesktopFirefoxUserAgent
        }

        return nil
    }

    public var localeIdentifier: String {
        if Locale.current.identifier == "en" {
            return "en_US"
        }

        return Locale.current.identifier
    }

    open var localeRegionIdentifier: String {
        if let regionCode = Locale.current.region?.identifier {
            return regionCode
        }

        return "US"
    }

    open var localeLanguageCode: String {
        if let languageCode = Locale.current.language.languageCode?.identifier {
            return languageCode
        }

        return "en"
    }

    open var localeWebIdentifier: String {
        localeIdentifier.replacingOccurrences(of: "_", with: "-")
    }

    public required init() {}

    // MARK: - Auth

    open func loadAuthSettings() {}

    open func storeAuthSettings() {}

    public func clearAuthSettings() {
        guard let currentAccountIdentifier = accountIdentifier else {
            return
        }

        let url = URL(fileURLWithPath: String.documentDirectory.appendingPathComponent(currentAccountIdentifier + ".settings"))
        try? FileManager.default.removeItem(at: url)
    }
}

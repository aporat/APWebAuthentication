import Foundation
import APUserAgentGenerator

@MainActor
open class Authentication {
    public var accountIdentifier: String?

    public var authSettingsURL: URL? {
        guard let currentAccountIdentifier = accountIdentifier,
              let documentsURL = FileManager.documentsDirectoryURL else {
            return nil
        }
        
        let fileName = currentAccountIdentifier + ".settings"
        
        return documentsURL.appendingPathComponent(fileName)
    }

    // MARK: - User Agent

    open var browserMode: UserAgentMode?
    open var customUserAgent: String?

    open var userAgent: String? {
        if let currentUserAgent = customUserAgent, !currentUserAgent.isEmpty {
            return currentUserAgent
        } else if browserMode == .default || browserMode == .ios || browserMode == .iphone {
            return APWebBrowserAgentBuilder.builder().generate()
        } else if browserMode == .iosChrome {
            return APWebBrowserAgentBuilder.builder().withDevice(iOSDevice()).withBrowser(ChromeBrowser()).generate()
        } else if browserMode == .webView {
            return nil
        } else if browserMode == .android {
            return APWebBrowserAgentBuilder.builder().withDevice(AndroidDevice(deviceModel: "Pixel 7")).withBrowser(ChromeBrowser(version: "123.0.6312.86")).generate()
        } else if browserMode == .desktop {
            return APWebBrowserAgentBuilder.builder().withDevice(MacDevice()).withBrowser(ChromeBrowser()).generate()
        } else if browserMode == .desktopFirefox {
            return APWebBrowserAgentBuilder.builder().withDevice(MacDevice()).withBrowser(FirefoxBrowser()).generate()
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

    open func loadAuthSettings() async {}

    open func storeAuthSettings() async {}

    public func clearAuthSettings() async {
        guard let url = authSettingsURL else {
            return
        }
        
        try? await Task.detached {
            try FileManager.default.removeItem(at: url)
        }.value
    }
}

import Foundation

public enum ProviderBrowserMode: String {
    case `default`
    case webView = "webview"
    case ios
    case iosChrome = "ios-chrome"
    case iphone
    case android
    case desktop
    case desktopFirefox = "desktop-firefox"

    public init?(_ rawValue: String?) {
        guard let currentRawValue = rawValue, let value = ProviderBrowserMode(rawValue: currentRawValue) else {
            return nil
        }
        self = value
    }
}

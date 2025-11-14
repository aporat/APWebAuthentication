import Foundation

public enum UserAgentMode: String, Codable, Sendable {
    case `default`
    case webView = "webview"
    case ios
    case iosChrome = "ios-chrome"
    case iphone
    case android
    case desktop
    case desktopFirefox = "desktop-firefox"

    public init?(_ string: String?) {
        guard let rawValue = string else {
            return nil
        }
        
        self.init(rawValue: rawValue)
    }
}

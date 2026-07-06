import Foundation
import WebKit

public final class TikTokWebAuthViewController: WebAuthViewController {

    // MARK: - Data

    fileprivate var auth: TikTokWebAuthentication
    fileprivate var loggedIn = false

    // MARK: - UIViewController

    public init(auth: TikTokWebAuthentication, authURL: URL?, redirectURL: URL?) {
        self.auth = auth
        super.init(authURL: authURL, redirectURL: redirectURL)
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - WKNavigationDelegate

    /// TikTok completes login by setting session cookies rather than by
    /// delivering tokens on the callback URL, so instead of the base class's
    /// cancel-and-complete redirect handling, allow the navigation, reload the
    /// auth URL, and verify the cookies in `didFinish`.
    override public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences
    ) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        if redirectURL == nil {
            checkForAuthTokens()
        }

        if let urlString = navigationAction.request.url?.absoluteString,
           let currentRedirectURL = redirectURL?.absoluteString,
           !urlString.isEmpty,
           urlString.contains(currentRedirectURL) {
            showHUD()
            loggedIn = true

            // make sure we dont get stuck loading
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) { [weak self] in
                self?.hideHUD()
                self?.loadRequest()
            }
        }

        return (.allow, preferences)
    }

    override public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if loggedIn {
            checkForAuthTokens()
        }

        super.webView(webView, didFinish: navigation)
    }

    fileprivate func checkForAuthTokens() {
        Task {
            let cookies = await self.getCookies()

            self.auth.setCookies(cookies)
            self.auth.loadAuthTokens(forceLoad: true)

            if self.auth.isAuthorized {
                self.didStopLoading()

                let handler = self.completionHandler
                self.completionHandler = nil

                let url = URL(string: "tiktok://auth-complete") ?? URL(string: "about:blank")!
                self.dismiss(animated: true) {
                    handler?(.success((url, cookies)))
                }
            }
        }
    }
}

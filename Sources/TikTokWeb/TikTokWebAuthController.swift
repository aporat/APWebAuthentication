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

    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - WKNavigationDelegate

    override public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        if redirectURL == nil {
            checkForAuthTokens()
        }

        if let urlString = navigationAction.request.url?.absoluteString, let currentRedirectURL = redirectURL?.absoluteString, !urlString.isEmpty {
            if urlString.contains(currentRedirectURL) {
                showHUD()
                loggedIn = true

                // make sure we dont get stuck loading
                // This is fine, as `asyncAfter` runs on the main queue.
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                    self.hideHUD()
                    self.loadRequest()
                }
            }
        }

        decisionHandler(.allow, preferences)
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

                let result: [String: String] = [:]
                
                self.dismiss(animated: true) {
                    self.completionHandler?(.success(result))
                    self.completionHandler = nil
                }
            }
        }
    }
}

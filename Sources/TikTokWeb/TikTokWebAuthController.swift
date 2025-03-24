import UIKit
import WebKit

public final class TikTokWebAuthViewController: AuthViewController {
    // MARK: - Data

    fileprivate var auth: TikTokWebAuthentication
    fileprivate var loggedIn = false

    // MARK: - UIViewController

    public init(auth: TikTokWebAuthentication, authURL: URL?, redirectURL: URL?, completionHandler: AuthViewController.CompletionHandler? = nil) {
        self.auth = auth
        super.init(authURL: authURL, redirectURL: redirectURL, completionHandler: completionHandler)
    }

    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - WKNavigationDelegate

    override public func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if redirectURL == nil {
            checkForAuthTokens()
        }

        if let urlString = navigationAction.request.url?.absoluteString, let currentRedirectURL = redirectURL?.absoluteString, !urlString.isEmpty {
            if urlString.contains(currentRedirectURL) {
                showHUD()
                loggedIn = true

                // make sure we dont get stuck loading
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                    self.hideHUD()
                    self.loadRequest()
                }
            }
        }

        decisionHandler(.allow)
    }

    override public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if loggedIn {
            checkForAuthTokens()
        }

        super.webView(webView, didFinish: navigation)
    }

    fileprivate func checkForAuthTokens() {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in

            self.auth.setCookies(cookies)
            self.auth.loadAuthTokens(forceLoad: true)

            if self.auth.isAuthorized {
                self.didStopLoading()

                let result = ["cookies": cookies]
                DispatchQueue.main.async {
                    self.dismiss(animated: true) {
                        self.completionHandler?(.success(result))
                        self.completionHandler = nil
                    }
                }
            }
        }
    }
}

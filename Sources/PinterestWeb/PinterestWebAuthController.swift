import Foundation
import WebKit

@MainActor
public final class PinterestWebAuthController: WebAuthViewController {
    // MARK: - Data

    fileprivate var auth: PinterestWebAuthentication
    fileprivate var loggedIn = false

    // MARK: - UIViewController

    public init(auth: PinterestWebAuthentication, authURL: URL?, redirectURL: URL?, completionHandler: WebAuthViewController.CompletionHandler? = nil) {
        self.auth = auth
        super.init(authURL: authURL, redirectURL: redirectURL, completionHandler: completionHandler)
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

            if urlString == "https://www.pinterest.com/me/" ||
                urlString == "https://www.pinterest.com/" ||
                urlString == currentRedirectURL
            {
                loggedIn = true
                showHUD()

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

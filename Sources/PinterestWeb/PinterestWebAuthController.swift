import Foundation
import SwiftyBeaver
import WebKit

@MainActor
public final class PinterestWebAuthController: WebAuthViewController {

    // MARK: - Data

    fileprivate var auth: PinterestWebAuthentication

    fileprivate var isVerifying = false

    // MARK: - Initialization

    public init(auth: PinterestWebAuthentication, authURL: URL?, redirectURL: URL?) {
        self.auth = auth
        super.init(authURL: authURL, redirectURL: redirectURL)
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Redirect Logic Override

    @objc override public func checkForRedirect(url: URL?) -> Bool {
        guard let url = url else { return false }
        let urlString = url.absoluteString

        log.debug("Pinterest Check Redirect: \(urlString)")

        // Only check for redirect AFTER the initial page has loaded
        // This prevents immediate dismissal on first navigation
        guard initialLoaded else {
            log.debug("⏭️ Skipping redirect check - initial page not yet loaded")
            return false
        }

        if let currentRedirectURL = redirectURL?.absoluteString, !currentRedirectURL.isEmpty, urlString.hasPrefix(currentRedirectURL) {
            log.info("✅ Redirect URL MATCH detected: \(urlString)")
            attemptAuthVerification()
            return true
        }

        if urlString.contains("pinterest.com/settings/") ||
            urlString.contains("pinterest.com/me/") ||
            urlString == "https://www.pinterest.com/" {

            log.info("✅ Pinterest Success Page Detected: \(urlString)")
            attemptAuthVerification()

            return true
        }

        return false
    }

    // MARK: - WKNavigationDelegate Override

    override public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Check for custom redirect first
        if checkForRedirect(url: webView.url) {
            didStopLoading()
            return
        }

        // Otherwise, call super to handle default behavior
        super.webView(webView, didFinish: navigation)
    }

    // MARK: - Verification Logic

    fileprivate func attemptAuthVerification() {
        guard !isVerifying else { return }
        isVerifying = true

        showHUD()

        Task {
            let success = await retryCookieCheck(maxRetries: 5, delaySeconds: 0.5)

            self.hideHUD()
            self.didStopLoading()

            if success {
                log.info("🔐 Pinterest Authorization Successful")

                self.dismiss(animated: true) {
                    self.completionHandler?(.success([:]))
                    self.completionHandler = nil
                }
            } else {
                log.error("❌ Pinterest Authorization Failed: Cookies not found after retries")

                let error = APWebAuthenticationError.sessionExpired(reason: "Login detected, but session cookies could not be retrieved. Please try again.")

                self.dismiss(animated: true) {
                    self.completionHandler?(.failure(error))
                    self.completionHandler = nil
                }
            }

            self.isVerifying = false
        }
    }

    /// Polls for cookies. Returns true if authorized, false if timed out.
    private func retryCookieCheck(maxRetries: Int, delaySeconds: Double) async -> Bool {
        for attempt in 1...maxRetries {
            log.debug("🍪 Checking cookies (Attempt \(attempt)/\(maxRetries))...")

            let cookies = await self.getCookies()
            self.auth.setCookies(cookies)
            self.auth.loadAuthTokens(forceLoad: true)

            if self.auth.isAuthorized {
                return true
            }

            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        }

        return false
    }
}

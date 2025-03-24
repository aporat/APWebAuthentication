import UIKit
import WebKit

public final class TikTokWebSignatureController: WebTokensViewController {
    // MARK: - Data

    fileprivate var auth: TikTokWebAuthentication

    // MARK: - UIViewController

    public init(auth: TikTokWebAuthentication, url: URL, forURL: URL, completionHandler: @escaping AuthViewController.CompletionHandler) {
        self.auth = auth
        super.init(url: url, forURL: forURL, completionHandler: completionHandler)
    }

    public required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadRequest() {
        storeCookiesToWebView(auth.getCookies()) {
            super.loadRequest()
        }
    }

    override public func requestLoaded(_ url: URL, forURL _: URL) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in

            self.auth.setCookies(cookies)
            self.auth.loadAuthTokens(forceLoad: true)

            if let signature = url.parameters["_signature"] {
                let result: [String: Any] = [
                    "signature": signature,
                    "url": url,
                ]

                self.completionHandler(.success(result))
            }
        }
    }

    public func getSignature(_ forURL: URL, _ completion: ((String?) -> Void)? = nil) {
        loadJavascript("window.byted_acrawler.sign({ url: \"" + forURL.absoluteString + "\" })", completion)
    }

    override public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if let results = message.body as? [String: Any], let responseUrl = results["responseURL"] as? String {
            if responseUrl.contains(forURL.absoluteString), let url = URL(string: responseUrl), !isFinished {
                //   log.debug( "responseURL " + responseUrl)
                requestLoaded(url, forURL: forURL)
                isFinished = true
            }
        }
    }
}

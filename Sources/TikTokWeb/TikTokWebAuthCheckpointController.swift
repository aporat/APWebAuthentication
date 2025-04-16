import Foundation
import WebKit

public final class TikTokWebAuthCheckpointController: WebTokensViewController {
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
}

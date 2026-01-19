import Foundation
import WebKit

public final class TikTokWebSignatureController: WebTokenInterceptorViewController {
    
    // MARK: - Data
    /*
    fileprivate var auth: TikTokWebAuthentication
    
    // MARK: - UIViewController
    
    public init(auth: TikTokWebAuthentication, url: URL, forURL: URL, completionHandler: @escaping WebAuthViewController.CompletionHandler) {
        self.auth = auth
        super.init(url: url, forURL: forURL, completionHandler: completionHandler)
    }
    
    @available(*, unavailable)
    public required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadRequest() {
        Task {
            await storeCookies(auth.getCookies())
            super.loadRequest()
        }
    }
    
    @MainActor
    override public func requestLoaded(_ url: URL, forURL _: URL) async {
        let cookies = await getCookies()
        
        self.auth.setCookies(cookies)
        self.auth.loadAuthTokens(forceLoad: true)
        
        if let signature = url.parameters["_signature"] {
            let _: [String: Any] = [
                "signature": signature,
                "url": url,
            ]
        }
    }
    
    public func getSignature(_ forURL: URL, _ completion: ((String?) -> Void)? = nil) {
        Task {
            await self.loadJavascript("window.byted_acrawler.sign({ url: \"" + forURL.absoluteString + "\" })")
        }
    }
    
    override public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if let results = message.body as? [String: Any], let responseUrl = results["responseURL"] as? String {
            if responseUrl.contains(forURL.absoluteString), let url = URL(string: responseUrl), !isFinished {
                Task {
                    await requestLoaded(url, forURL: forURL)
                }
                isFinished = true
            }
        }
    }*/
}

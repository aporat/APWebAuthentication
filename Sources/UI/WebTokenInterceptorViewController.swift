import UIKit
import WebKit
import SnapKit

@MainActor
public protocol WebTokensDelegate: AnyObject {
    func didStepLoaded(_ progress: Float)
}

@MainActor
open class WebTokenInterceptorViewController: UIViewController, WKNavigationDelegate {
    public weak var delegate: WebTokensDelegate?
    public var customUserAgent: String?
    open var isFinished = false
    
    // REFACTOR: Use the Sendable-safe typealias from WebAuthViewController
    open var completionHandler: WebAuthViewController.CompletionHandler
    var url: URL
    var forURL: URL
    
    fileprivate let XMLHttpRequestInjectCodeHandler = "handler"
    fileprivate let XMLHttpRequestInjectCode = """
    var open = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function() {
        this.addEventListener("load", function() {
            var message = {"status" : this.status, "responseURL" : this.responseURL}
            webkit.messageHandlers.handler.postMessage(message);
        });
    
        open.apply(this, arguments);
    };
    """
    
    fileprivate lazy var webViewConfiguration: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()
        // BUG FIX: Use a non-persistent store to avoid sharing
        // cookies/data with the main browser.
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        
        return config
    }()
    
    lazy open var webView: WKWebView = {
        let view = WKWebView(frame: CGRect.zero, configuration: self.webViewConfiguration)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isMultipleTouchEnabled = true
        view.autoresizesSubviews = true
        view.scrollView.alwaysBounceVertical = true
        
        return view
    }()
    
    public init(url: URL, forURL: URL, completionHandler: @escaping WebAuthViewController.CompletionHandler) {
        self.url = url
        self.forURL = forURL
        self.completionHandler = completionHandler
        
        super.init(nibName: nil, bundle: nil)
        
        let userScript = WKUserScript(source: XMLHttpRequestInjectCode, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webViewConfiguration.userContentController.addUserScript(userScript)
        webViewConfiguration.userContentController.add(self, name: "handler")
        
        webView.navigationDelegate = self
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        view.addSubview(webView)
    }
    
    public required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc public func didCancel() {
        guard !isFinished else { return }
        isFinished = true
        completionHandler(.failure(APWebAuthenticationError.canceled))
        self.dismiss(animated: true, completion: nil)
    }
    
    open func loadRequest() {
        if let userAgent = customUserAgent {
            webView.customUserAgent = userAgent
        }
        
        webView.load(URLRequest(url: url))
    }
    
    public func stopLoading() {
        webView.stopLoading()
        
        // Safely remove observer
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        webViewConfiguration.userContentController.removeScriptMessageHandler(forName: XMLHttpRequestInjectCodeHandler)
        webViewConfiguration.userContentController.removeAllUserScripts()
        webViewConfiguration.userContentController.removeAllContentRuleLists()
    }
    
    override public func updateViewConstraints() {
        super.updateViewConstraints()
        
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    public func webView(_: WKWebView, decidePolicyFor _: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    public func webView(_: WKWebView, didFinish _: WKNavigation!) {
        // This class is already @MainActor, so DispatchQueue is redundant,
        // but `asyncAfter` is a fine way to do a delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
            if !self.isFinished {
                self.completionHandler(.failure(APWebAuthenticationError.unknown))
            }
        }
    }
    
    // MARK: - KVO
    
    override open func observeValue(forKeyPath keyPath: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            // CONCURRENCY FIX: KVO callbacks are not guaranteed to be on the
            // main thread. We must hop to the @MainActor to safely
            // call the delegate.
            Task { @MainActor in
                self.delegate?.didStepLoaded(Float(self.webView.estimatedProgress))
            }
        }
    }
    
    // MARK: - Actions
    
    @discardableResult
    public func loadJavascript(_ javaScriptString: String) async -> String? {
        let result = try? await webView.evaluateJavaScript(javaScriptString)
        return result as? String
    }
    
    public func getCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }
    
    public func storeCookies(_ cookies: [HTTPCookie]?) async {
        guard let cookies = cookies, !cookies.isEmpty else { return }
        
        await withTaskGroup(of: Void.self) { group in
            for cookie in cookies {
                group.addTask {
                    await self.webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
                }
            }
        }
    }
    
    open func requestLoaded(_: URL, forURL _: URL) async {
        guard !isFinished else { return }
        isFinished = true
        completionHandler(.success(nil)) // nil is valid for [String: String]?
        self.dismiss(animated: true, completion: nil)
    }
}

@MainActor
extension WebTokenInterceptorViewController: WKScriptMessageHandler {
    // This delegate method is guaranteed to be on the main thread,
    // so it's safe to access all @MainActor properties.
    public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if let results = message.body as? [String: Any], let responseUrl = results["responseURL"] as? String {
            if responseUrl.contains(forURL.absoluteString), let url = URL(string: responseUrl) {
                Task {
                    await requestLoaded(url, forURL: forURL)
                }
            }
        }
    }
}

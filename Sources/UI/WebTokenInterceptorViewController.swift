import UIKit
import WebKit
import SnapKit

@MainActor
public protocol WebTokensDelegate: AnyObject {
    func didStepLoaded(_ progress: Float)
}

@MainActor
open class WebTokenInterceptorViewController: UIViewController, WKNavigationDelegate {
    
    // MARK: - Properties
    
    public weak var delegate: WebTokensDelegate?
    public var customUserAgent: String?
    open var isFinished = false
    public var isInteractive = false
    
    private var continuation: CheckedContinuation<Void, Error>?
    
    var url: URL
    public var forURL: URL?
    
    // MARK: - JS Injection
    
    fileprivate let XMLHttpRequestInjectCodeHandler = "handler"
    fileprivate let XMLHttpRequestInjectCode = """
        var open = XMLHttpRequest.prototype.open;
        var setRequestHeader = XMLHttpRequest.prototype.setRequestHeader;
        
        XMLHttpRequest.prototype.open = function() {
            this._headers = {};
            this.addEventListener("load", function() {
                var message = {
                    "status" : this.status, 
                    "responseURL" : this.responseURL,
                    "requestHeaders" : this._headers,
                    "responseHeaders" : this.getAllResponseHeaders()
                };
                webkit.messageHandlers.handler.postMessage(message);
            });
        
            open.apply(this, arguments);
        };
        
        XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
            if (!this._headers) this._headers = {};
            this._headers[header] = value;
            setRequestHeader.apply(this, arguments);
        };
        """
    
    // MARK: - UI Components
    
    fileprivate lazy var webViewConfiguration: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()
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
    
    // MARK: - Initialization
    
    public init(url: URL, forURL: URL) {
        self.url = url
        self.forURL = forURL
        
        super.init(nibName: nil, bundle: nil)
        
        let userScript = WKUserScript(source: XMLHttpRequestInjectCode, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webViewConfiguration.userContentController.addUserScript(userScript)
        webViewConfiguration.userContentController.add(self, name: "handler")
        
        webView.navigationDelegate = self
        view.addSubview(webView)
    }
    
    public required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Cancel", comment: ""),
            style: .plain,
            target: self,
            action: #selector(didCancel)
        )
    }
    
    public func start() async throws {
        guard !isFinished else { return }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            self.loadRequest()
        }
    }
    
    @objc public func didCancel() {
        log.debug("User cancelled WebView authentication")
        
        isFinished = true
        continuation?.resume(throwing: APWebAuthenticationError.canceled)
        continuation = nil
        
        self.dismiss(animated: true, completion: nil)
    }
    
    open func loadRequest() {
        if let userAgent = customUserAgent {
            webView.customUserAgent = userAgent
        }
        
        log.debug("Loading Request: \(url.absoluteString)")
        webView.load(URLRequest(url: url))
    }
    
    public func stopLoading() {
        webView.stopLoading()
        
        webViewConfiguration.userContentController.removeScriptMessageHandler(forName: XMLHttpRequestInjectCodeHandler)
        webViewConfiguration.userContentController.removeAllUserScripts()
        webViewConfiguration.userContentController.removeAllContentRuleLists()
    }
    
    override public func updateViewConstraints() {
        super.updateViewConstraints()
        
        webView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            
            make.left.right.bottom.equalToSuperview()
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    public func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            log.debug("WebView Navigating to: \(url.absoluteString)")
        }
        decisionHandler(.allow)
    }
    
    open func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        log.debug("WebView Started Loading: \(webView.url?.absoluteString ?? "nil")")
    }
    
    open func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        log.debug("WebView Navigation Failed: \(error.localizedDescription)")
    }
    
    open func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        log.debug("WebView Finished Loading: \(webView.url?.absoluteString ?? "nil")")
        
        if !isInteractive {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
                guard let self = self else { return }
                
                if !self.isFinished {
                    log.debug("WebView Timeout Reached")
                    self.isFinished = true
                    self.continuation?.resume(throwing: APWebAuthenticationError.unknown)
                    self.continuation = nil
                    
                    self.dismiss(animated: true)
                }
            }
        } else {
            log.debug("WebView finished loading, waiting for user interaction...")
        }
    }
    
    // MARK: - Actions
    
    @discardableResult
    public func loadJavascript(_ javaScriptString: String) async -> String? {
        let result = try? await webView.evaluateJavaScript(javaScriptString)
        log.debug("JS Result: \(String(describing: result))")
        return result as? String
    }
    
    public func getCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }
    
    public func loadCookiesToWebView(_ cookies: [HTTPCookie]?) async {
        guard let cookies = cookies, !cookies.isEmpty else { return }
        
        await withTaskGroup(of: Void.self) { group in
            for cookie in cookies {
                group.addTask {
                    await self.webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
                }
            }
        }
    }
    
    open func requestLoaded(_: URL, forURL _: URL?, requestHeaders: [String: Any]?, responseHeaders: String?) async {
        guard !isFinished else { return }
        isFinished = true
        continuation?.resume(returning: ())
        continuation = nil
        self.dismiss(animated: true, completion: nil)
    }
    
    open func shouldIntercept(responseURL: URL) -> Bool {
        
        if let forURL = forURL {
            return responseURL.absoluteString.contains(forURL.absoluteString)
        }
        
        return false
    }
    
}

@MainActor
extension WebTokenInterceptorViewController: WKScriptMessageHandler {
    public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if let results = message.body as? [String: Any],
           let responseUrlString = results["responseURL"] as? String,
           let responseUrl = URL(string: responseUrlString) {
            
            log.debug("Intercepted Target AJAX: \(responseUrlString)")

            if shouldIntercept(responseURL: responseUrl) {
                log.debug("Intercepted Target AJAX: \(responseUrlString)")
                
                let requestHeaders = results["requestHeaders"] as? [String: Any]
                let responseHeaders = results["responseHeaders"] as? String
                
                Task {
                    await requestLoaded(responseUrl, forURL: forURL, requestHeaders: requestHeaders, responseHeaders: responseHeaders)
                }
            }
        }
    }
}

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
    
    private var continuation: CheckedContinuation<Void, Error>?
    
    var url: URL
    var forURL: URL
    
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
    
    public func start() async throws {
        guard !isFinished else { return }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            self.loadRequest()
        }
    }
    
    open func loadRequest() {
        if let userAgent = customUserAgent {
            webView.customUserAgent = userAgent
        }
        
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
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    public func webView(_: WKWebView, decidePolicyFor _: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    public func webView(_: WKWebView, didFinish _: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
            guard let self = self else { return }
            
            if !self.isFinished {
                self.isFinished = true
                self.continuation?.resume(throwing: APWebAuthenticationError.unknown)
                self.continuation = nil
            }
        }
    }
    
    // MARK: - Actions
    
    @discardableResult
    public func loadJavascript(_ javaScriptString: String) async -> String? {
        let result = try? await webView.evaluateJavaScript(javaScriptString)
        log.debug(result)
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
    
    open func requestLoaded(_: URL, forURL _: URL, requestHeaders: [String: Any]?, responseHeaders: String?) async {

        guard !isFinished else { return }
        isFinished = true
        continuation?.resume(returning: ())
        continuation = nil
        self.dismiss(animated: true, completion: nil)
    }
}

@MainActor
extension WebTokenInterceptorViewController: WKScriptMessageHandler {
    public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        // Ensure we can cast the body to a Dictionary
        if let results = message.body as? [String: Any],
           let responseUrl = results["responseURL"] as? String {
            
            log.debug(results)

            if responseUrl.contains(forURL.absoluteString), let url = URL(string: responseUrl) {
                let requestHeaders = results["requestHeaders"] as? [String: Any]
                
                let responseHeaders = results["responseHeaders"] as? String

                Task {
                    await requestLoaded(url, forURL: forURL, requestHeaders: requestHeaders, responseHeaders: responseHeaders)
                }
            }
        }
    }
}

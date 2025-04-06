import UIKit
import WebKit

public protocol WebTokensDelegate: AnyObject {
    func didStepLoaded(_ progress: Float)
}

open class WebTokensViewController: UIViewController, WKNavigationDelegate {
    public weak var delegate: WebTokensDelegate?
    public var customUserAgent: String?
    open var isFinished = false
    open var completionHandler: BaseAuthViewController.CompletionHandler
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
        config.processPool = WKProcessPool()
        config.websiteDataStore = WKWebsiteDataStore.default()

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

    public init(url: URL, forURL: URL, completionHandler: @escaping AuthViewController.CompletionHandler) {
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

    open func loadRequest() {
        if let userAgent = customUserAgent {
            webView.customUserAgent = userAgent
        }

        webView.load(URLRequest(url: url))
    }

    public func stopLoading() {
        webView.stopLoading()
        
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

    deinit {
        webView.stopLoading()
        webView.scrollView.delegate = nil
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    // MARK: - WKNavigationDelegate

    public func webView(_: WKWebView, decidePolicyFor _: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    public func webView(_: WKWebView, didFinish _: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
            if !self.isFinished {
                self.completionHandler(.failure(APWebAuthenticationError.unknown))
            }
        }
    }

    // MARK: - KVO

    override open func observeValue(forKeyPath keyPath: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            delegate?.didStepLoaded(Float(webView.estimatedProgress))
        }
    }

    // MARK: - Actions

    public func loadJavascript(_ javaScriptString: String, _ completion: ((String?) -> Void)? = nil) {
        webView.evaluateJavaScript(javaScriptString) { result, error in
            if error == nil, let string = result as? String {
                completion?(string)
            } else {
                completion?(nil)
            }
        }
    }

    public func storeCookiesToWebView(_ cookies: [HTTPCookie]?, _ completion: @escaping () -> Void) {
        if let currentCookies = cookies, currentCookies.count > 0 {
            let dispatchGroup = DispatchGroup()

            for cookie in currentCookies {
                dispatchGroup.enter()

                webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
                    dispatchGroup.leave()
                }
            }

            dispatchGroup.notify(queue: .main) {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                    completion()
                }
            }
        } else {
            completion()
        }
    }

    open func requestLoaded(_: URL, forURL _: URL) {}
}

extension WebTokensViewController: WKScriptMessageHandler {
    public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if let results = message.body as? [String: Any], let responseUrl = results["responseURL"] as? String {
            if responseUrl.contains(forURL.absoluteString), let url = URL(string: responseUrl) {
                requestLoaded(url, forURL: forURL)
            }
        }
    }
}

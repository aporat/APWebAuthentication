import Foundation
import SnapKit
import SwifterSwift
import SwiftyJSON
@preconcurrency import WebKit
import UIKit

extension BaseAuthViewController {
    public typealias CompletionHandler = (Result<[String: Any]?, APWebAuthenticationError>) -> Void
}

extension BaseAuthViewController {
    public enum DismissButtonStyle: Int {
        case done
        case close
        case cancel
    }
}

@MainActor
open class BaseAuthViewController: UIViewController, WKNavigationDelegate {
    public var dismissButtonStyle: BaseAuthViewController.DismissButtonStyle = .cancel
    
    public var appearanceStyle: APWebAuthenticationSession.AppearanceStyle = .normal
    public var statusBarStyle = UIStatusBarStyle.default
    public var initialLoaded = false
    public var isJSONContentType = false
    
    public var completionHandler: CompletionHandler?
    public var authURL: URL?
    public var redirectURL: URL?
    public var customUserAgent: String? {
        get {
            webView.customUserAgent
        }
        set {
            webView.customUserAgent = newValue
        }
    }
    
    fileprivate var observerAdded = false // track the estimatedProgress observer
    
    // MARK: - UI Elements
    
    public var completedBarButtonItems = [UIBarButtonItem]()
    fileprivate var loadingBarButtonItems = [UIBarButtonItem]()
    
    fileprivate var refreshBarButtonItem: UIBarButtonItem!
    fileprivate var stopBarButtonItem: UIBarButtonItem!
    
    fileprivate var dismissBarButtonItem: UIBarButtonItem!
    
    fileprivate lazy var activityBarButtonItem: UIBarButtonItem = {
        let view = UIBarButtonItem(customView: self.activityIndicator)
        return view
    }()
    
    // Toolbar
    fileprivate lazy var actionBarBackBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "chevron.left"),
                               style: UIBarButtonItem.Style.plain,
                               target: self,
                               action: #selector(BaseAuthViewController.goBackTapped(_:)))
    }()
    
    fileprivate lazy var actionBarForwardBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "chevron.right"),
                               style: UIBarButtonItem.Style.plain,
                               target: self,
                               action: #selector(BaseAuthViewController.goForwardTapped(_:)))
    }()
    
    fileprivate lazy var actionSafariBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "safari"),
                               style: UIBarButtonItem.Style.plain,
                               target: self,
                               action: #selector(BaseAuthViewController.openInSafari(_:)))
    }()
    
    fileprivate lazy var actionBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"),
                               style: UIBarButtonItem.Style.plain,
                               target: self,
                               action: #selector(BaseAuthViewController.actionButtonTapped(_:)))
    }()
    
    fileprivate lazy var activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        
        view.frame = CGRect(x: 0, y: 0, width: 25, height: 25)
        view.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        view.sizeToFit()
        
        return view
    }()
    
    public lazy var progressView: UIProgressView = {
        let view = UIProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.trackTintColor = .clear
        
        return view
    }()
    
    open lazy var webViewConfiguration: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        
        return config
    }()
    
    open lazy var webView: WKWebView = {
        let view = WKWebView(frame: CGRect.zero, configuration: self.webViewConfiguration)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isMultipleTouchEnabled = true
        view.autoresizesSubviews = true
        view.scrollView.alwaysBounceVertical = true
        view.navigationDelegate = self
        
        return view
    }()
    
    // MARK: - UIViewController
    
    public init(authURL: URL?, redirectURL: URL?, completionHandler: AuthViewController.CompletionHandler? = nil) {
        self.authURL = authURL
        self.redirectURL = redirectURL
        self.completionHandler = completionHandler
        
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(webView)
        
        var dismissButtonLabel = NSLocalizedString("Cancel", comment: "")
        if dismissButtonStyle == .close {
            dismissButtonLabel = NSLocalizedString("Close", comment: "")
        } else if dismissButtonStyle == .done {
            dismissButtonLabel = NSLocalizedString("Done", comment: "")
        }
        
        refreshBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise")?.scaled(toWidth: 18), style: UIBarButtonItem.Style.plain, target: self, action: #selector(refresh(_:)))
        stopBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark")?.scaled(toWidth: 18), style: UIBarButtonItem.Style.plain, target: self, action: #selector(stop(_:)))
        
        
        loadingBarButtonItems = [stopBarButtonItem]
        dismissBarButtonItem = UIBarButtonItem(title: dismissButtonLabel, style: .plain, target: self, action: #selector(dismissCancelled(_:)))
        
        if appearanceStyle == .normal {
            completedBarButtonItems = [refreshBarButtonItem]
            
            navigationItem.leftBarButtonItems = [dismissBarButtonItem]
            navigationItem.rightBarButtonItems = [activityBarButtonItem]
            
            let newNavBarAppearance = UINavigationBarAppearance()
            newNavBarAppearance.configureWithOpaqueBackground()
            newNavBarAppearance.backgroundColor = UIColor(named: "BarTintColor")
            newNavBarAppearance.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(named: "TintColor")!]
            newNavBarAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(named: "TintColor")!]
            
            self.navigationController?.navigationBar.standardAppearance = newNavBarAppearance
            self.navigationController?.navigationBar.scrollEdgeAppearance = newNavBarAppearance
            self.navigationController?.navigationBar.compactAppearance = newNavBarAppearance
            self.navigationController?.navigationBar.compactScrollEdgeAppearance = newNavBarAppearance
        } else {
            let newNavBarAppearance = UINavigationBarAppearance()
            newNavBarAppearance.configureWithOpaqueBackground()
            
            if let currentNavigationController = navigationController, currentNavigationController.traitCollection.userInterfaceStyle == .dark {
                newNavBarAppearance.backgroundColor = UIColor(hex: 0x565656)!
            } else {
                newNavBarAppearance.backgroundColor = UIColor(hex: 0xF8F8F8)!
            }
            
            newNavBarAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(hex: 0x0079FF)!]
            
            self.navigationController?.navigationBar.standardAppearance = newNavBarAppearance
            self.navigationController?.navigationBar.scrollEdgeAppearance = newNavBarAppearance
            self.navigationController?.navigationBar.compactAppearance = newNavBarAppearance
            self.navigationController?.navigationBar.compactScrollEdgeAppearance = newNavBarAppearance
            
            let newToolbarBarAppearance = UIToolbarAppearance()
            newToolbarBarAppearance.configureWithOpaqueBackground()
            
            if let currentNavigationController = navigationController, currentNavigationController.traitCollection.userInterfaceStyle == .dark {
                newToolbarBarAppearance.backgroundColor = UIColor(hex: 0x565656)!
            } else {
                newToolbarBarAppearance.backgroundColor = UIColor(hex: 0xF8F8F8)!
            }
            
            self.navigationController?.toolbar.standardAppearance = newToolbarBarAppearance
            self.navigationController?.toolbar.scrollEdgeAppearance = newToolbarBarAppearance
            self.navigationController?.toolbar.compactAppearance = newToolbarBarAppearance
            self.navigationController?.toolbar.compactScrollEdgeAppearance = newToolbarBarAppearance
            
            setupToolbarItems()
        }
        
        activityIndicator.style = .medium
        
        // Register for changes to the userInterfaceStyle
        self.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
            // The handler is called only when the userInterfaceStyle changes
            if self.appearanceStyle == .safari, let currentNavigationController = self.navigationController {
                let newNavBarAppearance = UINavigationBarAppearance()
                newNavBarAppearance.configureWithOpaqueBackground()
                
                if currentNavigationController.traitCollection.userInterfaceStyle == .dark {
                    newNavBarAppearance.backgroundColor = UIColor(hex: 0x565656)!
                } else {
                    newNavBarAppearance.backgroundColor = UIColor(hex: 0xF8F8F8)!
                }
                
                newNavBarAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(hex: 0x0079FF)!]
                currentNavigationController.navigationBar.standardAppearance = newNavBarAppearance
                currentNavigationController.navigationBar.scrollEdgeAppearance = newNavBarAppearance
                currentNavigationController.navigationBar.compactAppearance = newNavBarAppearance
                currentNavigationController.navigationBar.compactScrollEdgeAppearance = newNavBarAppearance
                
                let newToolbarBarAppearance = UIToolbarAppearance()
                newToolbarBarAppearance.configureWithOpaqueBackground()
                
                if currentNavigationController.traitCollection.userInterfaceStyle == .dark {
                    newToolbarBarAppearance.backgroundColor = UIColor(hex: 0x565656)!
                } else {
                    newToolbarBarAppearance.backgroundColor = UIColor(hex: 0xF8F8F8)!
                }
                
                self.navigationController?.toolbar.standardAppearance = newToolbarBarAppearance
                self.navigationController?.toolbar.scrollEdgeAppearance = newToolbarBarAppearance
                self.navigationController?.toolbar.compactAppearance = newToolbarBarAppearance
                self.navigationController?.toolbar.compactScrollEdgeAppearance = newToolbarBarAppearance
                
                if currentNavigationController.traitCollection.userInterfaceStyle == .dark {
                    currentNavigationController.navigationBar.tintColor = UIColor(hex: 0x5A91F7)
                    currentNavigationController.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(hex: 0x5A91F7)!]
                    currentNavigationController.navigationBar.barTintColor = UIColor(hex: 0x565656)
                } else {
                    currentNavigationController.navigationBar.tintColor = UIColor(hex: 0x0079FF)
                    currentNavigationController.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(hex: 0x0079FF)!]
                    currentNavigationController.navigationBar.barTintColor = UIColor(hex: 0xF8F8F8)
                }
            }
        }
        
        
        view.setNeedsUpdateConstraints()
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !observerAdded, appearanceStyle == .safari {
            webView.navigationDelegate = self
            webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
            observerAdded = true
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if observerAdded {
            webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
            observerAdded = false
        }
    }
    
    override open func updateViewConstraints() {
        super.updateViewConstraints()
        
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        statusBarStyle
    }
    
    // MARK: - Toolbar
    
    fileprivate func setupToolbarItems() {
        toolbarItems = [actionBarBackBarButtonItem, UIBarButtonItem.flexibleSpace, actionBarForwardBarButtonItem, UIBarButtonItem.flexibleSpace, UIBarButtonItem.flexibleSpace, actionBarButtonItem, UIBarButtonItem.flexibleSpace, actionSafariBarButtonItem]
        
        
        let textTranformBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "textformat.size")?.scaled(toWidth: 23), style: UIBarButtonItem.Style.plain, target: self, action: #selector(textTransform(_:)))
        
        completedBarButtonItems = [refreshBarButtonItem, UIBarButtonItem.fixedSpace(width: 0), textTranformBarButtonItem]
        loadingBarButtonItems = [stopBarButtonItem, UIBarButtonItem.fixedSpace(width: 0), textTranformBarButtonItem]
        
        
        if appearanceStyle == .safari, let currentNavigationController = navigationController {
            
            currentNavigationController.toolbar.isTranslucent = false
            currentNavigationController.setToolbarHidden(false, animated: false)
            
            if presentingViewController == nil {
                navigationController?.toolbar.barTintColor = currentNavigationController.navigationBar.barTintColor
            } else {
                navigationController?.toolbar.barStyle = currentNavigationController.navigationBar.barStyle
            }
            navigationController?.toolbar.tintColor = currentNavigationController.navigationBar.tintColor
        }
        
        navigationItem.rightBarButtonItems = completedBarButtonItems
        navigationItem.leftBarButtonItems = [dismissBarButtonItem]
    }
    
    // MARK: - KVO
    
    override open func observeValue(forKeyPath keyPath: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            Task { @MainActor in
                self.updateProgressBar(Float(self.webView.estimatedProgress))
            }
        }
    }
    
    fileprivate func updateProgressBar(_ progress: Float) {
        if progress >= 1.0 {
            navigationController?.finishProgress()
        } else {
            navigationController?.setProgress(progress, animated: true)
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    open func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        didStartLoading()
    }
    
    open func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
        didStopLoading()
    }
    
    open func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
        didStopLoading()
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        isJSONContentType = navigationResponse.response.mimeType == "application/json"
        decisionHandler(.allow)
    }
    
    open func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        initialLoaded = true
        
        didStopLoading()
        
        if isJSONContentType {
            Task {
                await parseAndHandleJSONResponse()
            }
        }
    }
    
    private func parseAndHandleJSONResponse() async {
        guard let htmlString = await loadJavascript("document.body.innerText"), !htmlString.isEmpty else {
            return
        }
        
        let response = JSON(parseJSON: htmlString)
        var errorMessage: String?
        
        if let msg = response["meta"]["error_message"].string { errorMessage = msg }
        else if let msg = response["error_message"].string { errorMessage = msg }
        else if let msg = response["error"].string { errorMessage = msg }
        else if response["status"].stringValue == "failure", let msg = response["message"].string { errorMessage = msg }
        
        if let finalMessage = errorMessage, !finalMessage.isEmpty {
            completionHandler?(.failure(APWebAuthenticationError.failed(reason: finalMessage)))
            await dismiss(animated: true)
        }
    }
    
    // MARK: - Cookies
    
    public func storeCookiesToWebView(_ cookies: [HTTPCookie]?) async {
        guard let cookies = cookies, !cookies.isEmpty else { return }
        
        await withTaskGroup(of: Void.self) { group in
            for cookie in cookies {
                group.addTask {
                    await self.webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
                }
            }
        }
    }
    
    public func getAllCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }
    
    // MARK: - Actions
    
    open func loadRequest() {
        if let url = authURL {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    public func didStartLoading() {
        if appearanceStyle == .normal {
            activityIndicator.startAnimating()
            
            if navigationItem.rightBarButtonItems != [activityBarButtonItem] {
                navigationItem.rightBarButtonItems = [activityBarButtonItem]
            }
        } else {
            navigationItem.rightBarButtonItems = loadingBarButtonItems
            updateProgressBar(0.5)
            
            actionBarBackBarButtonItem.isEnabled = webView.canGoBack
            actionBarForwardBarButtonItem.isEnabled = webView.canGoForward
        }
    }
    
    public func didStopLoading() {
        if navigationItem.rightBarButtonItems != completedBarButtonItems {
            navigationItem.rightBarButtonItems = completedBarButtonItems
        }
        
        if appearanceStyle == .normal {
            activityIndicator.stopAnimating()
        } else {
            updateProgressBar(1.0)
            
            actionBarBackBarButtonItem.isEnabled = webView.canGoBack
            actionBarForwardBarButtonItem.isEnabled = webView.canGoForward
        }
    }
    
    @discardableResult
    public func loadJavascript(_ javaScriptString: String) async -> String? {
        do {
            let result = try await webView.evaluateJavaScript(javaScriptString)
            return result as? String
        } catch {
            return nil
        }
    }
    
    @objc func dismissCancelled(_: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true) {
                self?.completionHandler?(.failure(APWebAuthenticationError.loginCanceled))
            }
        }
    }
    
    @objc open func textTransform(_: Any?) {}
    
    @objc open func refresh(_: Any?) {
        initialLoaded = false
        loadRequest()
    }
    
    @objc fileprivate func stop(_: Any?) {
        initialLoaded = false
        
        webView.stopLoading()
        didStopLoading()
    }
    
    // MARK: - Toolbar Actions
    
    @objc fileprivate func goBackTapped(_: UIBarButtonItem) {
        webView.goBack()
    }
    
    @objc fileprivate func goForwardTapped(_: UIBarButtonItem) {
        webView.goForward()
    }
    
    @objc fileprivate func openInSafari(_: UIBarButtonItem) {
        if authURL != nil, let url: URL = ((webView.url != nil) ? webView.url : authURL) {
            UIApplication.shared.open(url, options: [:])
        }
    }
    
    @objc fileprivate func actionButtonTapped(_ sender: AnyObject) {
        if authURL != nil, let url: URL = ((webView.url != nil) ? webView.url : authURL) {
            let activities: [UIActivity] = [WebActivitySafari()]
            
            if url.absoluteString.hasPrefix("file:///") {
                let vc = UIDocumentInteractionController(url: url)
                vc.presentOptionsMenu(from: view.bounds, in: view, animated: true)
            } else {
                let activityController = UIActivityViewController(activityItems: [url], applicationActivities: activities)
                
                if let presentation = activityController.popoverPresentationController, let button = sender as? UIBarButtonItem {
                    presentation.permittedArrowDirections = UIPopoverArrowDirection.any
                    presentation.barButtonItem = button
                }
                
                present(activityController, animated: true)
            }
        }
    }
}

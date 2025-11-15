import Foundation
import SnapKit
import SwifterSwift
import SwiftyJSON
@preconcurrency import WebKit
import UIKit
import JGProgressHUD
import SwiftyBeaver

extension WebAuthViewController {
    public typealias CompletionHandler = (Result<[String: String]?, APWebAuthenticationError>) -> Void
}

extension WebAuthViewController {
    public enum DismissButtonStyle: Int {
        case done
        case close
        case cancel
    }
}

@MainActor
open class WebAuthViewController: UIViewController, WKNavigationDelegate {
    public var dismissButtonStyle: WebAuthViewController.DismissButtonStyle = .cancel
    
    public var appearanceStyle: APWebAuthSession.AppearanceStyle = .normal
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
    
    fileprivate lazy var loginHUD: JGProgressHUD = {
        let view = JGProgressHUD(style: .dark)
        return view
    }()
    
    public var existingSessionId: String?
    
    fileprivate var observerAdded = false
    
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
        return createToolbarButton(
            systemName: "chevron.left",
            selector: #selector(WebAuthViewController.goBackTapped(_:))
        )
    }()
    
    fileprivate lazy var actionBarForwardBarButtonItem: UIBarButtonItem = {
        return createToolbarButton(
            systemName: "chevron.right",
            selector: #selector(WebAuthViewController.goForwardTapped(_:))
        )
    }()
    
    fileprivate lazy var actionSafariBarButtonItem: UIBarButtonItem = {
        return createToolbarButton(
            systemName: "safari",
            selector: #selector(WebAuthViewController.openInSafari(_:))
        )
    }()
    
    fileprivate lazy var actionBarButtonItem: UIBarButtonItem = {
        return createToolbarButton(
            systemName: "square.and.arrow.up",
            selector: #selector(WebAuthViewController.actionButtonTapped(_:))
        )
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
        
        return view
    }()
    
    // MARK: - UIViewController
    
    public init(authURL: URL?, redirectURL: URL?, completionHandler: WebAuthViewController.CompletionHandler? = nil) {
        self.authURL = authURL
        self.redirectURL = redirectURL
        self.completionHandler = completionHandler
        
        super.init(nibName: nil, bundle: nil)
        log.debug("WebAuthViewController init for \(authURL?.host ?? "nil URL")")
    }
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        log.debug("WebAuthViewController viewDidLoad")
        
        webView.navigationDelegate = self
        
        view.addSubview(webView)
        
        var dismissButtonLabel = NSLocalizedString("Cancel", comment: "")
        if dismissButtonStyle == .close {
            dismissButtonLabel = NSLocalizedString("Close", comment: "")
        } else if dismissButtonStyle == .done {
            dismissButtonLabel = NSLocalizedString("Done", comment: "")
        }
        
        refreshBarButtonItem = createNavBarButton(
            systemName: "arrow.clockwise",
            selector: #selector(refresh(_:))
        )
        stopBarButtonItem = createNavBarButton(
            systemName: "xmark",
            selector: #selector(stop(_:))
        )
        
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
        
        self.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
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
        
        let dataStore = self.webView.configuration.websiteDataStore
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        log.debug("Clearing WKWebsiteDataStore...")
        dataStore.fetchDataRecords(ofTypes: allTypes) { [weak self] records in
            guard let self = self else { return }
            dataStore.removeData(ofTypes: allTypes, for: records) {
                log.debug("DataStore cleared. Calling loadRequest().")
                self.loadRequest()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            if let navBar = self.navigationItem.titleView as? AuthNavBarView {
                navBar.showSecure()
            }
        }
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !observerAdded, appearanceStyle == .safari {
            log.debug("WebAuthVC viewWillAppear. Adding KVO observer.")
            webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
            observerAdded = true
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if observerAdded {
            log.debug("WebAuthVC viewWillDisappear. Removing KVO observer.")
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
        
        
        let textTranformButton = createToolbarButton(
            systemName: "textformat.size",
            selector: #selector(textTransform(_:))
        )
        
        completedBarButtonItems = [refreshBarButtonItem, UIBarButtonItem.fixedSpace(width: 0), textTranformButton]
        loadingBarButtonItems = [stopBarButtonItem, UIBarButtonItem.fixedSpace(width: 0), textTranformButton]
        
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
                log.verbose("KVO: estimatedProgress = \(self.webView.estimatedProgress)")
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
    open func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        
        let urlString = navigationAction.request.url?.absoluteString ?? "nil URL"
        log.debug("decidePolicyFor navigationAction: \(urlString)")
        
        if let currentRedirectURL = redirectURL?.absoluteString, !urlString.isEmpty {
            
            log.debug("Comparing against redirectURL: \(currentRedirectURL)")
            
            if urlString.hasPrefix(currentRedirectURL) {
                log.info("Redirect URL detected. Processing callback.")
                let result = navigationAction.request.url?.getResponse()
                
                if case let .success(params) = result {
                    log.info("Callback success. Calling completionHandler.")
                    self.completionHandler?(.success(params))
                } else if case let .failure(error) = result {
                    log.warning("Callback failure. Calling completionHandler with error: \(error.localizedDescription)")
                    self.completionHandler?(.failure(error))
                }
                self.completionHandler = nil
                
                log.debug("Dismissing view controller.")
                self.dismiss(animated: true)
                
                decisionHandler(.cancel, preferences)
                return
            }
        }
        
        log.debug("Allowing navigation.")
        decisionHandler(.allow, preferences)
    }
    
    open func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        log.debug("didStartProvisionalNavigation")
        didStartLoading()
    }
    
    open func webView(_: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Don't log "Frame load interrupted" as a warning, it's expected on redirects.
        if (error as NSError).code == 102 {
            log.debug("didFail navigation: \(error.localizedDescription)")
        } else {
            log.warning("didFail navigation: \(error.localizedDescription)")
        }
        didStopLoading()
    }
    
    open func webView(_: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Don't log "Frame load interrupted" as a warning, it's expected on redirects.
        if (error as NSError).code == 102 {
            log.debug("didFailProvisionalNavigation: \(error.localizedDescription)")
        } else {
            log.warning("didFailProvisionalNavigation: \(error.localizedDescription)")
        }
        didStopLoading()
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let urlString = navigationResponse.response.url?.absoluteString ?? "nil URL"
        log.debug("decidePolicyFor navigationAction (JSON Check): \(urlString)")

        isJSONContentType = navigationResponse.response.mimeType == "application/json"
        decisionHandler(.allow)
    }
    
    open func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        log.debug("didFinish navigation.")
        initialLoaded = true
        
        didStopLoading()
        
        if isJSONContentType {
            log.debug("Content-Type is JSON, attempting to parse...")
            Task {
                await parseAndHandleJSONResponse()
            }
        }
    }
    
    private func parseAndHandleJSONResponse() async {
        guard let htmlString = await loadJavascript("document.body.innerText"), !htmlString.isEmpty else {
            log.error("Failed to get HTML string from javascript.")
            return
        }
        
        let response = JSON(parseJSON: htmlString)
        var errorMessage: String?
        
        if let msg = response["meta"]["error_message"].string { errorMessage = msg }
        else if let msg = response["error_message"].string { errorMessage = msg }
        else if let msg = response["error"].string { errorMessage = msg }
        else if response["status"].stringValue == "failure", let msg = response["message"].string { errorMessage = msg }
        
        if let finalMessage = errorMessage, !finalMessage.isEmpty {
            log.warning("Found error in JSON response: \(finalMessage)")
            completionHandler?(.failure(APWebAuthenticationError.failed(reason: finalMessage)))
            dismiss(animated: true)
        }
    }
    
    // MARK: - Cookies
    
    public func storeCookies(_ cookies: [HTTPCookie]?) async {
        guard let cookies = cookies, !cookies.isEmpty else { return }
        
        log.debug("Storing \(cookies.count) cookies...")
        await withTaskGroup(of: Void.self) { group in
            for cookie in cookies {
                group.addTask {
                    await self.webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
                }
            }
        }
    }
    
    public func getCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[HTTPCookie], Never>) in
            log.debug("Getting all cookies from WKHTTPCookieStore...")
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                Task { @MainActor in
                    log.debug("Found \(cookies.count) cookies.")
                    continuation.resume(returning: cookies)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    open func loadRequest() {
        if let url = authURL {
            log.info("Loading request: \(url.absoluteString)")
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            log.error("loadRequest() called but authURL is nil.")
        }
    }
    
    public func didStartLoading() {
        log.verbose("didStartLoading (UI update)")
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
        log.verbose("didStopLoading (UI update)")
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
            log.error("evaluateJavaScript failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    @objc func dismissCancelled(_: Any?) {
        log.info("dismissCancelled: User tapped cancel button.")
        self.dismiss(animated: true) {
            self.completionHandler?(.failure(APWebAuthenticationError.canceled))
            self.completionHandler = nil
        }
    }
    
    @objc open func textTransform(_: Any?) {}
    
    @objc open func refresh(_: Any?) {
        log.debug("refresh tapped.")
        initialLoaded = false
        loadRequest()
    }
    
    @objc fileprivate func stop(_: Any?) {
        log.debug("stop tapped.")
        initialLoaded = false
        
        webView.stopLoading()
        didStopLoading()
    }
    
    // MARK: - Toolbar Actions
    
    @objc fileprivate func goBackTapped(_: UIBarButtonItem) {
        log.debug("goBackTapped")
        webView.goBack()
    }
    
    @objc fileprivate func goForwardTapped(_: UIBarButtonItem) {
        log.debug("goForwardTapped")
        webView.goForward()
    }
    
    @objc fileprivate func openInSafari(_: UIBarButtonItem) {
        log.debug("openInSafari tapped.")
        if authURL != nil, let url: URL = ((webView.url != nil) ? webView.url : authURL) {
            UIApplication.shared.open(url, options: [:])
        }
    }
    
    @objc fileprivate func actionButtonTapped(_ sender: AnyObject) {
        log.debug("actionButtonTapped")
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
    
    // MARK: - UI Loading
    
    public func showHUD() {
        log.verbose("showHUD")
        self.loginHUD.show(in: self.view)
    }
    
    public func hideHUD() {
        log.verbose("hideHUD")
        self.loginHUD.dismiss()
    }
    
    // MARK: - Button Creation Helpers
    
    /// Creates a UIBarButtonItem with a custom UIButton for navigation bars
    private func createNavBarButton(systemName: String, selector: Selector) -> UIBarButtonItem {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.addTarget(self, action: selector, for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30) // Explicit frame
        button.imageView?.contentMode = .scaleAspectFit
        return UIBarButtonItem(customView: button)
    }
    
    /// Creates a UIBarButtonItem with a custom UIButton for toolbars
    private func createToolbarButton(systemName: String, selector: Selector) -> UIBarButtonItem {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.addTarget(self, action: selector, for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 40, height: 30) // Explicit frame
        button.imageView?.contentMode = .scaleAspectFit // <-- Already set here
        return UIBarButtonItem(customView: button)
    }
}

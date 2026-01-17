import Foundation
import SnapKit
import SwifterSwift
@preconcurrency import SwiftyJSON
@preconcurrency import WebKit
import UIKit
import JGProgressHUD
import SwiftyBeaver

// MARK: - Type Aliases

extension WebAuthViewController {
    public typealias CompletionHandler = (Result<[String: Any]?, APWebAuthenticationError>) -> Void
    public typealias DismissButtonStyle = WebAuthNavigationManager.DismissButtonStyle
}

// MARK: - Web Auth View Controller

/// A view controller that handles web-based authentication flows.
///
/// This view controller presents a web view for OAuth, form-based login,
/// and other web authentication patterns. It manages the web view lifecycle,
/// navigation, and callback detection with a clean, modular architecture.
///
/// **Key Features:**
/// - Two appearance styles (normal and Safari-like)
/// - Automatic redirect URL detection and parsing
/// - Cookie management
/// - JavaScript execution
/// - JSON error response handling
/// - Progress tracking
///
/// **Architecture:**
/// This class delegates responsibilities to specialized manager classes:
/// - `WebAuthNavigationManager`: Handles navigation bar and toolbar
/// - `WebAuthCookieManager`: Manages HTTP cookies
/// - `WebAuthJavaScriptBridge`: Executes JavaScript
/// - `WebAuthRedirectHandler`: Detects redirects and parses responses
///
/// **Example Usage:**
/// ```swift
/// let vc = WebAuthViewController(
///     authURL: URL(string: "https://api.instagram.com/oauth/authorize?...")!,
///     redirectURL: URL(string: "myapp://callback")!
/// )
///
/// vc.appearanceStyle = .safari
/// vc.completionHandler = { result in
///     switch result {
///     case .success(let params):
///         print("Authenticated:", params)
///     case .failure(let error):
///         print("Failed:", error)
///     }
/// }
///
/// let navController = UINavigationController(rootViewController: vc)
/// present(navController, animated: true)
/// ```
@MainActor
open class WebAuthViewController: UIViewController {
    
    // MARK: - Public Properties
    
    /// The dismiss button style for the navigation bar
    public var dismissButtonStyle: DismissButtonStyle = .cancel
    
    /// The visual appearance style (normal or Safari-like)
    public var appearanceStyle: APWebAuthSession.AppearanceStyle = .normal
    
    /// The status bar style to use when this view controller is presented
    public var statusBarStyle = UIStatusBarStyle.default
    
    /// Whether the initial page load has completed
    public var initialLoaded = false
    
    /// Whether the current response has a JSON content type
    public private(set) var isJSONContentType = false
    
    /// The completion handler called when authentication completes or fails
    public var completionHandler: CompletionHandler?
    
    /// The authentication URL to load
    public var authURL: URL?
    
    /// The redirect URL that signals authentication completion
    public var redirectURL: URL?
    
    /// Custom user agent string for the web view
    public var customUserAgent: String? {
        get { webView.customUserAgent }
        set { webView.customUserAgent = newValue }
    }
    
    /// An optional existing session ID (for app-specific use)
    public var existingSessionId: String?
    
    /// Progress view for tracking page load progress
    public lazy var progressView: UIProgressView = {
        let view = UIProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.trackTintColor = .clear
        return view
    }()
    
    // MARK: - Web View Configuration
    
    /// The web view configuration to use
    open lazy var webViewConfiguration: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        return config
    }()
    
    /// The web view that displays authentication pages
    open lazy var webView: WKWebView = {
        let view = WKWebView(frame: .zero, configuration: self.webViewConfiguration)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isMultipleTouchEnabled = true
        view.autoresizesSubviews = true
        view.scrollView.alwaysBounceVertical = true
        return view
    }()
    
    // MARK: - Private Properties - Managers
    
    private lazy var navigationManager: WebAuthNavigationManager = {
        let manager = WebAuthNavigationManager(
            viewController: self,
            webView: webView,
            appearanceStyle: appearanceStyle,
            dismissButtonStyle: dismissButtonStyle
        )
        setupNavigationCallbacks(manager)
        return manager
    }()
    
    private lazy var cookieManager: WebAuthCookieManager = {
        WebAuthCookieManager(webView: webView)
    }()
    
    private lazy var javaScriptBridge: WebAuthJavaScriptBridge = {
        WebAuthJavaScriptBridge(webView: webView)
    }()
    
    private lazy var redirectHandler: WebAuthRedirectHandler = {
        WebAuthRedirectHandler(redirectURL: redirectURL)
    }()
    
    // MARK: - Private Properties - UI
    
    private lazy var loginHUD: JGProgressHUD = {
        JGProgressHUD(style: .dark)
    }()
    
    private var progressObserver: NSKeyValueObservation?
    
    // MARK: - Initialization
    
    /// Creates a new web authentication view controller.
    ///
    /// - Parameters:
    ///   - authURL: The URL to load for authentication
    ///   - redirectURL: The callback URL that signals completion
    public init(authURL: URL?, redirectURL: URL?) {
        self.authURL = authURL
        self.redirectURL = redirectURL
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        setupWebView()
        setupNavigation()
        setupTraitObservation()
        clearWebsiteDataAndLoad()
        scheduleSecureLockDisplay()
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if appearanceStyle == .safari {
            setupProgressObserver()
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removeProgressObserver()
    }
    
    override open func updateViewConstraints() {
        super.updateViewConstraints()
        
        webView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }
    
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        statusBarStyle
    }
    
    // MARK: - Setup
    
    private func setupWebView() {
        webView.navigationDelegate = self
        view.addSubview(webView)
        view.setNeedsUpdateConstraints()
    }
    
    private func setupNavigation() {
        navigationManager.configure()
    }
    
    private func setupNavigationCallbacks(_ manager: WebAuthNavigationManager) {
        manager.onDismiss = { [weak self] in
            self?.handleDismiss()
        }
        
        manager.onRefresh = { [weak self] in
            self?.handleRefresh()
        }
        
        manager.onStop = { [weak self] in
            self?.handleStop()
        }
        
        manager.onBack = { [weak self] in
            self?.webView.goBack()
        }
        
        manager.onForward = { [weak self] in
            self?.webView.goForward()
        }
        
        manager.onOpenInSafari = { [weak self] in
            self?.handleOpenInSafari()
        }
        
        manager.onShare = { [weak self] sender in
            self?.handleShare(sender: sender)
        }
        
        manager.onTextTransform = { [weak self] in
            self?.textTransform(nil)
        }
    }
    
    private func setupTraitObservation() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.navigationManager.updateAppearance(for: self.traitCollection)
        }
    }
    
    private func setupProgressObserver() {
        guard progressObserver == nil else { return }
        
        progressObserver = webView.observe(\.estimatedProgress, options: .new) { [weak self] webView, _ in
            Task { @MainActor [weak self] in
                self?.navigationManager.updateProgress(Float(webView.estimatedProgress))
            }
        }
    }
    
    private func removeProgressObserver() {
        progressObserver?.invalidate()
        progressObserver = nil
    }
    
    private func scheduleSecureLockDisplay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
            if let navBar = self?.navigationItem.titleView as? AuthNavBarView {
                navBar.showSecure()
            }
        }
    }
    
    // MARK: - Website Data Management
    
    private func clearWebsiteDataAndLoad() {
        let dataStore = webView.configuration.websiteDataStore
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        dataStore.fetchDataRecords(ofTypes: allTypes) { [weak self] records in
            guard let self = self else { return }
            dataStore.removeData(ofTypes: allTypes, for: records) {
                self.loadRequest()
            }
        }
    }
    
    // MARK: - Public Methods - Cookie Management
    
    /// Stores cookies in the web view's cookie store.
    ///
    /// - Parameter cookies: The cookies to store
    public func storeCookies(_ cookies: [HTTPCookie]?) async {
        await cookieManager.store(cookies)
    }
    
    /// Retrieves all cookies from the web view's cookie store.
    ///
    /// - Returns: An array of HTTP cookies
    public func getCookies() async -> [HTTPCookie] {
        await cookieManager.getCookies()
    }
    
    // MARK: - Public Methods - JavaScript
    
    /// Executes JavaScript and returns the result as a string.
    ///
    /// - Parameter javaScriptString: The JavaScript code to execute
    /// - Returns: The result as a string, or `nil` if execution failed
    @discardableResult
    public func loadJavascript(_ javaScriptString: String) async -> String? {
        await javaScriptBridge.evaluateString(javaScriptString)
    }
    
    // MARK: - Public Methods - Loading
    
    /// Loads the authentication URL in the web view.
    open func loadRequest() {
        guard let url = authURL else { return }
        log.debug("🌐 Loading Request: \(url.absoluteString)")
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    /// Shows the loading state in the navigation bar.
    public func didStartLoading() {
        navigationManager.showLoading()
    }
    
    /// Hides the loading state in the navigation bar.
    public func didStopLoading() {
        navigationManager.hideLoading()
    }
    
    // MARK: - Public Methods - HUD
    
    /// Shows a progress HUD overlay.
    public func showHUD() {
        loginHUD.show(in: view)
    }
    
    /// Hides the progress HUD overlay.
    public func hideHUD() {
        loginHUD.dismiss()
    }
    
    // MARK: - Public Methods - Text Transform
    
    /// Override this method to provide custom text transform functionality.
    ///
    /// This is called when the text transform button is tapped in Safari-style mode.
    @objc open func textTransform(_: Any?) {
        // Override in subclass
    }
}

// MARK: - WKNavigationDelegate

extension WebAuthViewController: WKNavigationDelegate {
    
    open func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        let urlString = navigationAction.request.url?.absoluteString ?? "nil URL"
        log.debug("🕸 WKWebView Navigation Action: \(urlString)")
        
        // Allow subclasses to check for custom redirects first
        if checkForRedirect(url: navigationAction.request.url) {
            decisionHandler(.cancel, preferences)
            return
        }
        
        if handleRedirect(url: navigationAction.request.url) {
            decisionHandler(.cancel, preferences)
            return
        }
        
        decisionHandler(.allow, preferences)
    }
    
    /// Override this method in subclasses to provide custom redirect detection logic.
    /// Return `true` if the URL should be treated as a redirect (canceling navigation),
    /// or `false` to continue with standard redirect handling.
    ///
    /// - Parameter url: The URL to check
    /// - Returns: `true` if custom redirect handling was performed, `false` otherwise
    @objc open func checkForRedirect(url: URL?) -> Bool {
        return false
    }
    
    open func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        let urlString = navigationResponse.response.url?.absoluteString ?? "nil URL"
        let mimeType = navigationResponse.response.mimeType ?? "unknown"
        log.debug("🕸 WKWebView Navigation Response: \(urlString) | MIME: \(mimeType)")
        
        if handleRedirect(url: navigationResponse.response.url) {
            decisionHandler(.cancel)
            return
        }
        
        if let mimeType = navigationResponse.response.mimeType {
            isJSONContentType = mimeType == "application/json"
        }
        
        decisionHandler(.allow)
    }
    
    open func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        let urlString = webView.url?.absoluteString ?? "nil URL"
        log.debug("🚀 WKWebView Started Provisional Navigation: \(urlString)")
        didStartLoading()
    }
    
    open func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        log.error("❌ WKWebView Navigation Failed: \(error.localizedDescription)")
        
        if let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
            log.debug("❌ Failing URL: \(failingURL.absoluteString)")
            if handleRedirect(url: failingURL) {
                return
            }
        }
        
        didStopLoading()
    }
    
    open func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        let nsError = error as NSError
        log.error("❌ WKWebView Provisional Navigation Failed: \(error.localizedDescription)")
        
        if let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
            log.debug("❌ Provisional Failing URL: \(failingURL.absoluteString)")
            if handleRedirect(url: failingURL) {
                return
            }
        }
        
        didStopLoading()
    }
    
    open func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let urlString = webView.url?.absoluteString ?? "nil URL"
        log.debug("🏁 WKWebView Finished Navigation: \(urlString)")
        
        initialLoaded = true
        didStopLoading()
        
        if handleRedirect(url: webView.url) {
            return
        }
        
        if isJSONContentType {
            Task {
                await parseAndHandleJSONResponse()
            }
        }
    }
}

// MARK: - Private Methods - Redirect Handling

private extension WebAuthViewController {
    
    /// Handles redirect URL detection and completion.
    ///
    /// - Parameter url: The URL to check
    /// - Returns: `true` if the URL matched the redirect URL, `false` otherwise
    func handleRedirect(url: URL?) -> Bool {
        guard let result = redirectHandler.checkRedirect(url: url) else {
            return false
        }
        
        // Complete authentication
        switch result {
        case .success(let params):
            completionHandler?(.success(params))
        case .failure(let error):
            completionHandler?(.failure(error))
        }
        
        completionHandler = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true)
        }
        
        return true
    }
    
    /// Parses JSON response from the web page and handles errors.
    func parseAndHandleJSONResponse() async {
        guard let htmlString = await javaScriptBridge.evaluateString("document.body.innerText"),
              !htmlString.isEmpty else {
            return
        }
        
        if let error = redirectHandler.parseJSONError(from: htmlString) {
            completionHandler?(.failure(error))
            dismiss(animated: true)
        }
    }
}

// MARK: - Private Methods - Action Handlers

private extension WebAuthViewController {
    
    func handleDismiss() {
        dismiss(animated: true) { [weak self] in
            self?.completionHandler?(.failure(.canceled))
            self?.completionHandler = nil
        }
    }
    
    func handleRefresh() {
        initialLoaded = false
        loadRequest()
    }
    
    func handleStop() {
        initialLoaded = false
        webView.stopLoading()
        didStopLoading()
    }
    
    func handleOpenInSafari() {
        guard let url = webView.url ?? authURL else { return }
        UIApplication.shared.open(url, options: [:])
    }
    
    func handleShare(sender: UIBarButtonItem) {
        guard let url = webView.url ?? authURL else { return }
        
        let activities: [UIActivity] = [WebActivitySafari()]
        
        if url.absoluteString.hasPrefix("file:///") {
            let documentController = UIDocumentInteractionController(url: url)
            documentController.presentOptionsMenu(from: view.bounds, in: view, animated: true)
        } else {
            let activityController = UIActivityViewController(
                activityItems: [url],
                applicationActivities: activities
            )
            
            if let presentation = activityController.popoverPresentationController {
                presentation.permittedArrowDirections = .any
                presentation.barButtonItem = sender
            }
            
            present(activityController, animated: true)
        }
    }
}

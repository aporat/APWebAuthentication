import SnapKit
import UIKit
import WebKit

// MARK: - Configuration

/// Configuration for web token interceptor
public struct WebTokenInterceptorConfiguration {
    /// The URL to load in the web view
    public let url: URL

    /// The target URL to intercept (optional)
    public let targetURL: URL?

    /// Custom user agent string
    public let customUserAgent: String?

    /// Whether the view requires user interaction (no timeout)
    public let isInteractive: Bool

    /// Timeout interval for non-interactive mode (default: 60 seconds)
    public let timeout: TimeInterval

    /// Whether to use persistent website data store
    public let usePersistentDataStore: Bool

    /// Cancel button title
    public let cancelButtonTitle: String

    public init(
        url: URL,
        targetURL: URL? = nil,
        customUserAgent: String? = nil,
        isInteractive: Bool = false,
        timeout: TimeInterval = 60,
        usePersistentDataStore: Bool = false,
        cancelButtonTitle: String = NSLocalizedString("Cancel", comment: "")
    ) {
        self.url = url
        self.targetURL = targetURL
        self.customUserAgent = customUserAgent
        self.isInteractive = isInteractive
        self.timeout = timeout
        self.usePersistentDataStore = usePersistentDataStore
        self.cancelButtonTitle = cancelButtonTitle
    }
}

// MARK: - Intercepted Request Data

/// Represents an intercepted HTTP request
public struct InterceptedRequest: Sendable {
    public let responseURL: URL
    public let targetURL: URL?
    public let requestHeaders: [String: String]
    public let responseHeaders: [String: String]
    public let statusCode: Int

    init(responseURL: URL, targetURL: URL?, requestHeaders: [String: Any]?, responseHeaders: String?, statusCode: Int) {
        self.responseURL = responseURL
        self.targetURL = targetURL
        self.statusCode = statusCode

        // Parse request headers
        var parsedRequestHeaders: [String: String] = [:]
        if let headers = requestHeaders {
            for (key, value) in headers {
                parsedRequestHeaders[key] = String(describing: value)
            }
        }
        self.requestHeaders = parsedRequestHeaders

        // Parse response headers
        var parsedResponseHeaders: [String: String] = [:]
        if let headers = responseHeaders {
            let lines = headers.components(separatedBy: "\n")
            for line in lines {
                let parts = line.components(separatedBy: ": ")
                if parts.count == 2 {
                    parsedResponseHeaders[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        self.responseHeaders = parsedResponseHeaders
    }
}

// MARK: - Delegate Protocol

@MainActor
public protocol WebTokenInterceptorDelegate: AnyObject {
    /// Called when loading progress changes
    func webTokenInterceptor(_ controller: WebTokenInterceptorViewController, didUpdateProgress progress: Float)

    /// Called when a request is intercepted (optional override point)
    func webTokenInterceptor(_ controller: WebTokenInterceptorViewController, didIntercept request: InterceptedRequest) async
}

extension WebTokenInterceptorDelegate {
    public func webTokenInterceptor(_ controller: WebTokenInterceptorViewController, didUpdateProgress progress: Float) {
        // Default implementation (optional)
    }

    public func webTokenInterceptor(_ controller: WebTokenInterceptorViewController, didIntercept request: InterceptedRequest) async {
        // Default implementation (optional)
    }
}

// MARK: - JavaScript Injection Manager

/// Manages JavaScript injection for XMLHttpRequest interception
private final class JavaScriptInjectionManager {
    static let handlerName = "handler"

    static let xmlHttpRequestInterceptorCode = """
        (function() {
            const open = XMLHttpRequest.prototype.open;
            const setRequestHeader = XMLHttpRequest.prototype.setRequestHeader;

            XMLHttpRequest.prototype.open = function() {
                this._headers = {};
                this.addEventListener("load", function() {
                    const message = {
                        status: this.status,
                        responseURL: this.responseURL,
                        requestHeaders: this._headers || {},
                        responseHeaders: this.getAllResponseHeaders()
                    };
                    webkit.messageHandlers.\(handlerName).postMessage(message);
                });

                open.apply(this, arguments);
            };

            XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
                if (!this._headers) this._headers = {};
                this._headers[header] = value;
                setRequestHeader.apply(this, arguments);
            };
        })();
        """

    @MainActor static func createUserScript() -> WKUserScript {
        WKUserScript(
            source: xmlHttpRequestInterceptorCode,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }
}

// MARK: - View Controller State

private enum ViewControllerState {
    case idle
    case loading
    case waitingForIntercept
    case completed
    case cancelled
    case failed(APWebAuthenticationError)

    var isFinished: Bool {
        switch self {
        case .completed, .cancelled, .failed:
            return true
        case .idle, .loading, .waitingForIntercept:
            return false
        }
    }
}

// MARK: - Web Token Interceptor View Controller

@MainActor
open class WebTokenInterceptorViewController: UIViewController {

    // MARK: - Properties

    public weak var delegate: WebTokenInterceptorDelegate?

    private let configuration: WebTokenInterceptorConfiguration
    private var state: ViewControllerState = .idle
    private var continuation: CheckedContinuation<Void, Error>?
    private var timeoutTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// Whether the authentication flow has finished
    public var isFinished: Bool {
        state.isFinished
    }

    /// The URL being loaded
    public var url: URL {
        configuration.url
    }

    /// The target URL to intercept
    public var targetURL: URL? {
        configuration.targetURL
    }

    // MARK: - UI Components

    private lazy var webViewConfiguration: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()

        // Configure data store
        config.websiteDataStore = configuration.usePersistentDataStore
            ? .default()
            : .nonPersistent()

        // Add JavaScript injection
        let userScript = JavaScriptInjectionManager.createUserScript()
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(self, name: JavaScriptInjectionManager.handlerName)

        return config
    }()

    open lazy var webView: WKWebView = {
        let view = WKWebView(frame: .zero, configuration: webViewConfiguration)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isMultipleTouchEnabled = true
        view.autoresizesSubviews = true
        view.scrollView.alwaysBounceVertical = true
        view.navigationDelegate = self
        return view
    }()

    // MARK: - Initialization

    public init(configuration: WebTokenInterceptorConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    /// Convenience initializer for backward compatibility
    public convenience init(url: URL, forURL: URL) {
        let config = WebTokenInterceptorConfiguration(url: url, targetURL: forURL)
        self.init(configuration: config)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timeoutTask?.cancel()
    }

    // MARK: - Lifecycle

    override open func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupConstraints()
    }

    private func setupUI() {
        view.addSubview(webView)

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: configuration.cancelButtonTitle,
            style: .plain,
            target: self,
            action: #selector(handleCancelTapped)
        )
    }

    private func setupConstraints() {
        webView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.left.right.bottom.equalToSuperview()
        }
    }

    // MARK: - Public API

    /// Start the web authentication flow
    public func start() async throws(APWebAuthenticationError) {
        guard !state.isFinished else {
            log.debug("WebTokenInterceptor: Already finished, ignoring start()")
            return
        }

        do {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.state = .loading
                loadRequest()
            }
        } catch let error as APWebAuthenticationError {
            throw error
        } catch {
            throw APWebAuthenticationError.unknown
        }
    }

    /// Stop loading and cleanup
    public func stopLoading() {
        log.debug("WebTokenInterceptor: Stopping loading")
        timeoutTask?.cancel()
        webView.stopLoading()
        cleanupWebView()
    }

    // MARK: - Request Loading

    open func loadRequest() {
        if let userAgent = configuration.customUserAgent {
            webView.customUserAgent = userAgent
        }

        log.debug("WebTokenInterceptor: Loading URL: \(configuration.url.absoluteString)")
        webView.load(URLRequest(url: configuration.url))
    }

    // MARK: - Timeout Handling

    private func startTimeoutIfNeeded() {
        guard !configuration.isInteractive else {
            log.debug("WebTokenInterceptor: Interactive mode, no timeout")
            return
        }

        log.debug("WebTokenInterceptor: Starting timeout of \(configuration.timeout) seconds")

        timeoutTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.configuration.timeout * 1_000_000_000))

            guard !Task.isCancelled else { return }

            self.handleTimeout()
        }
    }

    private func handleTimeout() {
        guard !state.isFinished else { return }

        log.debug("WebTokenInterceptor: Timeout reached")
        finishWithError(.timeout)
    }

    // MARK: - Actions

    @objc private func handleCancelTapped() {
        log.debug("WebTokenInterceptor: User cancelled")
        finishWithError(.canceled)
    }

    // MARK: - JavaScript Execution

    @discardableResult
    public func evaluateJavaScript(_ script: String) async throws -> Any? {
        do {
            let result = try await webView.evaluateJavaScript(script)
            log.debug("WebTokenInterceptor: JavaScript result: \(String(describing: result))")
            return result
        } catch {
            log.debug("WebTokenInterceptor: JavaScript error: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Cookie Management

    public func getCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

    public func loadCookies(_ cookies: [HTTPCookie]) async {
        guard !cookies.isEmpty else { return }

        log.debug("WebTokenInterceptor: Loading \(cookies.count) cookies")

        await withTaskGroup(of: Void.self) { group in
            for cookie in cookies {
                group.addTask {
                    await self.webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
                }
            }
        }
    }

    // MARK: - Request Interception

    /// Determines whether a response URL should be intercepted
    open func shouldIntercept(responseURL: URL) -> Bool {
        guard let targetURL = configuration.targetURL else {
            return false
        }

        return responseURL.absoluteString.contains(targetURL.absoluteString)
    }

    /// Called when a request matching the target URL is intercepted
    open func handleInterceptedRequest(_ request: InterceptedRequest) async {
        guard !state.isFinished else {
            log.debug("WebTokenInterceptor: Already finished, ignoring intercepted request")
            return
        }

        log.debug("WebTokenInterceptor: Request intercepted successfully")

        // Notify delegate
        await delegate?.webTokenInterceptor(self, didIntercept: request)

        // Finish with success
        finishWithSuccess()
    }

    // MARK: - State Management

    private func finishWithSuccess() {
        guard !state.isFinished else { return }

        state = .completed
        timeoutTask?.cancel()
        continuation?.resume(returning: ())
        continuation = nil

        dismiss(animated: true)
    }

    private func finishWithError(_ error: APWebAuthenticationError) {
        guard !state.isFinished else { return }

        state = .failed(error)
        timeoutTask?.cancel()
        continuation?.resume(throwing: error)
        continuation = nil

        dismiss(animated: true)
    }

    // MARK: - Cleanup

    private func cleanupWebView() {
        let contentController = webViewConfiguration.userContentController
        contentController.removeScriptMessageHandler(forName: JavaScriptInjectionManager.handlerName)
        contentController.removeAllUserScripts()
        contentController.removeAllContentRuleLists()
    }
}

// MARK: - WKNavigationDelegate

extension WebTokenInterceptorViewController: WKNavigationDelegate {

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url {
            log.debug("WebTokenInterceptor: Navigating to: \(url.absoluteString)")
        }
        decisionHandler(.allow)
    }

    open func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        log.debug("WebTokenInterceptor: Started loading: \(webView.url?.absoluteString ?? "nil")")
    }

    open func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        log.debug("WebTokenInterceptor: Navigation failed: \(error.localizedDescription)")

        let nsError = error as NSError

        // Ignore cancelled errors
        guard nsError.domain != NSURLErrorDomain || nsError.code != NSURLErrorCancelled else {
            return
        }

        finishWithError(.connectionError(reason: error.localizedDescription, responseJSON: nil))
    }

    open func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        log.debug("WebTokenInterceptor: Finished loading: \(webView.url?.absoluteString ?? "nil")")

        state = .waitingForIntercept

        // Start timeout for non-interactive mode
        startTimeoutIfNeeded()
    }
}

// MARK: - WKScriptMessageHandler

extension WebTokenInterceptorViewController: WKScriptMessageHandler {

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let results = message.body as? [String: Any],
              let responseURLString = results["responseURL"] as? String,
              let responseURL = URL(string: responseURLString) else {
            log.debug("WebTokenInterceptor: Invalid message format")
            return
        }

        log.debug("WebTokenInterceptor: Intercepted AJAX request: \(responseURLString)")

        guard shouldIntercept(responseURL: responseURL) else {
            return
        }

        let statusCode = results["status"] as? Int ?? 0
        let requestHeaders = results["requestHeaders"] as? [String: Any]
        let responseHeaders = results["responseHeaders"] as? String

        let request = InterceptedRequest(
            responseURL: responseURL,
            targetURL: configuration.targetURL,
            requestHeaders: requestHeaders,
            responseHeaders: responseHeaders,
            statusCode: statusCode
        )

        Task {
            await handleInterceptedRequest(request)
        }
    }
}

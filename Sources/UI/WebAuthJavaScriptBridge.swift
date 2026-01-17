import Foundation
import WebKit

// MARK: - JavaScript Bridge

/// Manages JavaScript execution in a web authentication view.
///
/// This class provides a safe, async interface for evaluating JavaScript
/// in a WKWebView. It handles errors gracefully and provides type-safe
/// result parsing.
///
/// **Example Usage:**
/// ```swift
/// let bridge = WebAuthJavaScriptBridge(webView: webView)
///
/// // Execute JavaScript
/// if let title = await bridge.evaluateString("document.title") {
///     print("Page title:", title)
/// }
///
/// // Get JSON data
/// let json = await bridge.evaluateString("document.body.innerText")
/// ```
@MainActor
public final class WebAuthJavaScriptBridge {
    
    // MARK: - Private Properties
    
    private weak var webView: WKWebView?
    
    // MARK: - Initialization
    
    /// Creates a new JavaScript bridge for the given web view.
    ///
    /// - Parameter webView: The web view to execute JavaScript in
    public init(webView: WKWebView) {
        self.webView = webView
    }
    
    // MARK: - Public Methods
    
    /// Evaluates JavaScript and returns the result as a string.
    ///
    /// This method executes JavaScript code and attempts to convert the
    /// result to a string. If the result cannot be converted or an error
    /// occurs, `nil` is returned.
    ///
    /// - Parameter script: The JavaScript code to execute
    /// - Returns: The result as a string, or `nil` if execution failed
    ///
    /// **Example:**
    /// ```swift
    /// // Get page title
    /// if let title = await bridge.evaluateString("document.title") {
    ///     print(title)
    /// }
    ///
    /// // Get body text
    /// if let bodyText = await bridge.evaluateString("document.body.innerText") {
    ///     print(bodyText)
    /// }
    /// ```
    @discardableResult
    public func evaluateString(_ script: String) async -> String? {
        guard let webView = webView else { return nil }
        
        do {
            let result = try await webView.evaluateJavaScript(script)
            return result as? String
        } catch {
            return nil
        }
    }
    
    /// Evaluates JavaScript and returns the raw result.
    ///
    /// Use this method when you need access to the raw JavaScript result
    /// (which could be a number, boolean, dictionary, array, etc.).
    ///
    /// - Parameter script: The JavaScript code to execute
    /// - Returns: The result as Any, or `nil` if execution failed
    ///
    /// **Example:**
    /// ```swift
    /// // Get a number
    /// if let count = await bridge.evaluate("document.querySelectorAll('a').length") as? Int {
    ///     print("Found \(count) links")
    /// }
    ///
    /// // Get a boolean
    /// if let hasForm = await bridge.evaluate("document.querySelector('form') !== null") as? Bool {
    ///     print("Has form:", hasForm)
    /// }
    /// ```
    @discardableResult
    public func evaluate(_ script: String) async -> Any? {
        guard let webView = webView else { return nil }
        
        do {
            return try await webView.evaluateJavaScript(script)
        } catch {
            return nil
        }
    }
    
    /// Evaluates JavaScript and returns whether execution succeeded.
    ///
    /// Use this method when you want to run JavaScript for side effects
    /// and only care whether it succeeded or failed.
    ///
    /// - Parameter script: The JavaScript code to execute
    /// - Returns: `true` if execution succeeded, `false` otherwise
    ///
    /// **Example:**
    /// ```swift
    /// // Scroll to top
    /// await bridge.execute("window.scrollTo(0, 0)")
    ///
    /// // Submit a form
    /// await bridge.execute("document.querySelector('form').submit()")
    /// ```
    @discardableResult
    public func execute(_ script: String) async -> Bool {
        guard let webView = webView else { return false }
        
        do {
            _ = try await webView.evaluateJavaScript(script)
            return true
        } catch {
            return false
        }
    }
}

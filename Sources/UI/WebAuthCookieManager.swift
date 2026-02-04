import Foundation
import WebKit

// MARK: - Cookie Manager

/// Manages HTTP cookies for web authentication sessions.
///
/// This class provides a simple interface for storing and retrieving cookies
/// from a WKWebView's cookie store. It handles the async nature of cookie
/// operations and provides a Swift Concurrency-friendly API.
///
/// **Example Usage:**
/// ```swift
/// let manager = WebAuthCookieManager(webView: webView)
///
/// // Store cookies
/// let cookies = [HTTPCookie(...)]
/// await manager.store(cookies)
///
/// // Retrieve cookies
/// let storedCookies = await manager.getCookies()
/// ```
@MainActor
public final class WebAuthCookieManager {

    // MARK: - Private Properties

    private weak var webView: WKWebView?

    // MARK: - Initialization

    /// Creates a new cookie manager for the given web view.
    ///
    /// - Parameter webView: The web view whose cookie store to manage
    public init(webView: WKWebView) {
        self.webView = webView
    }

    // MARK: - Public Methods

    /// Stores multiple cookies in the web view's cookie store.
    ///
    /// This method stores all cookies concurrently for better performance.
    ///
    /// - Parameter cookies: The cookies to store, or `nil` to do nothing
    ///
    /// **Example:**
    /// ```swift
    /// let cookies = [
    ///     HTTPCookie(properties: [
    ///         .name: "session",
    ///         .value: "abc123",
    ///         .domain: "instagram.com",
    ///         .path: "/"
    ///     ])!
    /// ]
    /// await manager.store(cookies)
    /// ```
    public func store(_ cookies: [HTTPCookie]?) async {
        guard let cookies = cookies, !cookies.isEmpty else { return }
        guard let cookieStore = webView?.configuration.websiteDataStore.httpCookieStore else {
            return
        }

        await withTaskGroup(of: Void.self) { group in
            for cookie in cookies {
                group.addTask {
                    await cookieStore.setCookie(cookie)
                }
            }
        }
    }

    /// Retrieves all cookies from the web view's cookie store.
    ///
    /// - Returns: An array of all stored cookies
    ///
    /// **Example:**
    /// ```swift
    /// let cookies = await manager.getCookies()
    /// for cookie in cookies {
    ///     print("\(cookie.name): \(cookie.value)")
    /// }
    /// ```
    public func getCookies() async -> [HTTPCookie] {
        guard let cookieStore = webView?.configuration.websiteDataStore.httpCookieStore else {
            return []
        }

        return await withCheckedContinuation { (continuation: CheckedContinuation<[HTTPCookie], Never>) in
            cookieStore.getAllCookies { cookies in
                Task { @MainActor in
                    continuation.resume(returning: cookies)
                }
            }
        }
    }

    /// Clears all cookies from the web view's cookie store.
    ///
    /// This removes all HTTP cookies, which can be useful when starting
    /// a fresh authentication session.
    ///
    /// **Example:**
    /// ```swift
    /// await manager.clearAll()
    /// ```
    public func clearAll() async {
        guard let webView = webView else { return }

        let dataStore = webView.configuration.websiteDataStore
        let cookieTypes = Set([WKWebsiteDataTypeCookies])

        let records = await dataStore.dataRecords(ofTypes: cookieTypes)
        await dataStore.removeData(ofTypes: cookieTypes, for: records)
    }
}

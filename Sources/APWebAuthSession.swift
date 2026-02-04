import SwifterSwift
import SwiftyBeaver
import UIKit

// MARK: - Web Authentication Result

/// A thread-safe wrapper for web authentication result data.
///
/// This struct safely transports dictionary data across async/concurrent boundaries.
/// The data is constrained to Sendable types only, ensuring true thread safety.
///
/// **Usage:**
/// ```swift
/// let session = APWebAuthSession(accountType: accountType)
/// if let result = try await session.start(url: authURL, callbackURL: redirectURL) {
///     print("Auth data:", result.data)
/// }
/// ```
public struct APWebAuthResult: Sendable {

    /// The authentication response data from the web service.
    ///
    /// Typical contents include tokens, user IDs, and other auth-related information.
    /// Values are constrained to Sendable types for thread safety across async boundaries.
    public let data: [String: any Sendable]

    /// Creates a new authentication result.
    ///
    /// - Parameter data: The dictionary containing authentication response data
    public init(_ data: [String: any Sendable]) {
        self.data = data
    }
}

// MARK: - Appearance Styles

extension APWebAuthSession {

    /// Visual presentation styles for the authentication interface.
    ///
    /// Different styles provide distinct user experiences:
    /// - **Normal**: Standard app-styled presentation with custom branding
    /// - **Safari**: System Safari-like appearance mimicking web browser UI
    ///
    /// **Example:**
    /// ```swift
    /// let session = APWebAuthSession(accountType: instagram)
    /// session.appearanceStyle = .safari // Shows Safari-like UI
    /// ```
    public enum AppearanceStyle: Int, Sendable {

        /// Standard app-styled presentation.
        ///
        /// Features:
        /// - Custom app branding and colors
        /// - Simpler navigation controls
        /// - Better for in-app authentication flows
        case normal

        /// Safari-style browser presentation.
        ///
        /// Features:
        /// - System Safari-like appearance
        /// - Full browser toolbar with navigation controls
        /// - Includes permission dialog
        /// - Better for OAuth and trusted web flows
        case safari
    }
}

// MARK: - Presentation Context Provider

/// A protocol for providing the presentation context for authentication sessions.
///
/// Conforming types supply the view controller that will present the authentication
/// interface. This allows the session to integrate seamlessly into your app's
/// navigation flow without tightly coupling to specific view controllers.
///
/// **Implementation Example:**
/// ```swift
/// class LoginCoordinator: APWebAuthenticationPresentationContextProviding {
///     weak var rootViewController: UIViewController?
///
///     func presentationAnchor(for session: APWebAuthSession) -> UIViewController? {
///         return rootViewController
///     }
/// }
/// ```
///
/// - Note: This protocol requires `NSObjectProtocol` conformance for compatibility
///         with Objective-C runtime features and weak references.
@MainActor
public protocol APWebAuthenticationPresentationContextProviding: NSObjectProtocol {

    /// Returns the view controller to present the authentication interface from.
    ///
    /// The returned view controller should be:
    /// - Currently visible in the window hierarchy
    /// - Capable of presenting modal view controllers
    /// - Not already presenting another view controller
    ///
    /// - Parameter session: The authentication session requesting presentation
    /// - Returns: A view controller to present from, or `nil` if unavailable
    func presentationAnchor(for session: APWebAuthSession) -> UIViewController?
}

// MARK: - Logging

/// Global logger instance for the authentication system.
///
/// Uses SwiftyBeaver for structured logging with support for console, file,
/// and cloud destinations.
///
/// **Usage:**
/// ```swift
/// log.info("Starting authentication")
/// log.error("Failed to present: \(error)")
/// ```
public let log = SwiftyBeaver.self

// MARK: - Web Authentication Session

/// A session object that manages web-based authentication flows.
///
/// `APWebAuthSession` provides a complete solution for OAuth, form-based login,
/// and other web authentication patterns. It presents a web view that handles
/// the authentication process and captures the callback with authentication data.
///
/// **Key Features:**
/// - Two appearance styles (normal and Safari-like)
/// - Async/await API with typed errors
/// - Automatic callback URL detection and parsing
/// - Permission dialogs for Safari-style flows
/// - Customizable presentation and status bar styles
///
/// **Basic Usage:**
/// ```swift
/// // 1. Create a session
/// let session = APWebAuthSession(accountType: instagram)
/// session.appearanceStyle = .safari
/// session.presentationContextProvider = self
///
/// // 2. Start authentication
/// do {
///     if let result = try await session.start(
///         url: authURL,
///         callbackURL: URL(string: "myapp://callback")!
///     ) {
///         print("Logged in with data:", result.data)
///     }
/// } catch APWebAuthenticationError.canceled {
///     print("User canceled")
/// } catch {
///     print("Error:", error)
/// }
/// ```
///
/// **Advanced Configuration:**
/// ```swift
/// let session = APWebAuthSession(accountType: twitter)
///
/// // Customize appearance
/// session.appearanceStyle = .normal
/// session.statusBarStyle = .lightContent
///
/// // Set presentation provider
/// session.presentationContextProvider = coordinator
///
/// // Start with pre-configured view controller
/// let webVC = WebAuthViewController(authURL: authURL, redirectURL: callbackURL)
/// session.loginViewController = webVC
/// try await session.start()
/// ```
///
/// - Important: Sessions must be retained until authentication completes.
///              Deallocating the session early will cancel the authentication.
///
/// - Note: All methods must be called from the main actor/thread.
@MainActor
public final class APWebAuthSession {

    // MARK: - Public Properties

    /// The status bar style for the authentication interface.
    ///
    /// Controls the appearance of the status bar while the authentication
    /// view controller is presented.
    ///
    /// **Example:**
    /// ```swift
    /// session.statusBarStyle = .lightContent // For dark backgrounds
    /// ```
    ///
    /// - Note: Only applies when using `.normal` appearance style
    public var statusBarStyle: UIStatusBarStyle = .default

    /// The visual presentation style for the authentication interface.
    ///
    /// Choose between:
    /// - `.normal`: Standard app-styled presentation
    /// - `.safari`: Safari-like browser presentation with permission dialog
    ///
    /// Default is `.normal`.
    public var appearanceStyle: APWebAuthSession.AppearanceStyle = .normal

    /// The web view controller used for authentication.
    ///
    /// You can provide a pre-configured view controller or let the session
    /// create one automatically. If `nil` when calling `start()`, an error
    /// will be thrown.
    ///
    /// **Example:**
    /// ```swift
    /// let webVC = WebAuthViewController(authURL: url, redirectURL: callback)
    /// webVC.customUserAgent = "MyApp/1.0"
    /// session.loginViewController = webVC
    /// ```
    public var loginViewController: WebAuthViewController?

    /// The object that provides the view controller for presenting authentication.
    ///
    /// Set this to your coordinator, view controller, or other object that can
    /// provide the presentation context. Must implement
    /// `APWebAuthenticationPresentationContextProviding`.
    ///
    /// **Example:**
    /// ```swift
    /// session.presentationContextProvider = self
    /// ```
    public weak var presentationContextProvider: APWebAuthenticationPresentationContextProviding?

    // MARK: - Private Properties

    /// The account type/platform being authenticated.
    private let accountType: AccountType

    // MARK: - Initialization

    /// Creates a new web authentication session for the specified account type.
    ///
    /// - Parameter accountType: The social media platform or service being authenticated
    ///
    /// **Example:**
    /// ```swift
    /// let session = APWebAuthSession(accountType: AccountStore.instagram)
    /// ```
    public init(accountType: AccountType) {
        self.accountType = accountType
    }

    // MARK: - Authentication Flow

    /// Starts the authentication flow with the specified URLs.
    ///
    /// This convenience method creates a `WebAuthViewController` with the provided
    /// URLs and immediately starts the authentication process.
    ///
    /// - Parameters:
    ///   - URL: The authentication URL to load (e.g., OAuth authorization endpoint)
    ///   - callbackURL: The redirect URL to monitor for completion
    ///
    /// - Returns: Authentication result data if successful, or `nil` if no data
    ///
    /// - Throws: `APWebAuthenticationError` for various failure conditions:
    ///   - `.canceled`: User canceled or no presentation context available
    ///   - `.failed`: General failure during authentication
    ///   - `.connectionError`: Network connectivity issues
    ///   - Other specific authentication errors
    ///
    /// **Example:**
    /// ```swift
    /// let authURL = URL(string: "https://api.instagram.com/oauth/authorize?...")!
    /// let callbackURL = URL(string: "myapp://instagram-callback")!
    ///
    /// do {
    ///     if let result = try await session.start(url: authURL, callbackURL: callbackURL) {
    ///         let token = result.data["access_token"] as? String
    ///         print("Got token:", token)
    ///     }
    /// } catch APWebAuthenticationError.canceled {
    ///     print("User canceled login")
    /// }
    /// ```
    @discardableResult
    public func start(url URL: URL, callbackURL: URL) async throws(APWebAuthenticationError) -> APWebAuthResult? {
        loginViewController = WebAuthViewController(authURL: URL, redirectURL: callbackURL)
        return try await start()
    }

    /// Starts the authentication flow using the existing login view controller.
    ///
    /// This method expects `loginViewController` to already be configured.
    /// Use this variant when you need to customize the view controller before
    /// starting authentication.
    ///
    /// - Returns: Authentication result data if successful, or `nil` if no data
    ///
    /// - Throws: `APWebAuthenticationError` for various failure conditions
    ///
    /// **Flow:**
    /// 1. Shows permission dialog (Safari style only)
    /// 2. Presents the web authentication view controller
    /// 3. Monitors for redirect to callback URL
    /// 4. Parses and returns authentication data
    /// 5. Dismisses the view controller
    ///
    /// **Example:**
    /// ```swift
    /// let webVC = WebAuthViewController(authURL: authURL, redirectURL: callbackURL)
    /// webVC.customUserAgent = "MyApp/1.0"
    ///
    /// session.loginViewController = webVC
    /// let result = try await session.start()
    /// ```
    @discardableResult
    public func start() async throws(APWebAuthenticationError) -> APWebAuthResult? {
        do {
            // Safari style shows a permission dialog first
            if appearanceStyle == .safari {
                let loginRequested = await showLoginPermission()
                guard loginRequested else {
                    throw APWebAuthenticationError.canceled
                }
            }

            // Bridge callback-based web view to async/await
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<APWebAuthResult?, Error>) in

                guard let loginVC = self.loginViewController else {
                    log.error("loginViewController is nil before completionHandler can be set.")
                    continuation.resume(throwing: APWebAuthenticationError.canceled)
                    return
                }

                // Set up completion handler for web view controller
                loginVC.completionHandler = { [weak self] (result: Result<[String: any Sendable]?, APWebAuthenticationError>) in

                    switch result {
                    case .success(let params):
                        if let params = params {
                            let safeResult = APWebAuthResult(params)
                            continuation.resume(returning: safeResult)
                        } else {
                            continuation.resume(returning: nil)
                        }

                    case .failure(let error):
                        log.error("completionHandler: Failure. Resuming with error: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }

                    // Clean up after authentication completes
                    guard let self else { return }

                    self.loginViewController?.dismiss(animated: true) {
                        self.loginViewController = nil
                    }
                }

                // Present the authentication interface
                do {
                    if appearanceStyle == .safari {
                        try self.presentSafariStyle()
                    } else {
                        try self.presentNormalStyle()
                    }
                } catch {
                    log.error("Failed to present login view controller: \(error.localizedDescription)")
                    let authError = (error as? APWebAuthenticationError) ?? .failed(reason: error.localizedDescription)
                    continuation.resume(throwing: authError)
                }
            }
        } catch {
            log.error("APWebAuthSession start() threw an error: \(error.localizedDescription)")
            self.loginViewController = nil

            throw (error as? APWebAuthenticationError) ?? .failed(reason: error.localizedDescription)
        }
    }

    // MARK: - Permission Dialog

    /// Shows the Safari-style login permission dialog.
    ///
    /// Displays an alert asking the user for permission to use the website
    /// for sign in, similar to Safari's built-in authentication dialogs.
    ///
    /// - Returns: `true` if the user tapped Continue, `false` if canceled
    ///
    /// **Dialog Example:**
    /// ```
    /// "MyApp" Wants to Use "instagram.com" to Sign In
    ///
    /// This allows the app and website to share
    /// information about you.
    ///
    /// [Cancel] [Continue]
    /// ```
    private func showLoginPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            let title = String(format: NSLocalizedString("“%@” Wants to Use “%@” to Sign In", comment: ""), UIApplication.shared.shortAppName, self.accountType.webAddress)
            let message = NSLocalizedString("This allows the app and website to share information about you.", comment: "")
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

            alert.addAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                continuation.resume(returning: false)
            }
            alert.addAction(title: NSLocalizedString("Continue", comment: ""), style: .default) { _ in
                continuation.resume(returning: true)
            }
            alert.preferredAction = alert.actions.last

            if let vc = self.presentationContextProvider?.presentationAnchor(for: self), vc.isVisible {
                vc.present(alert, animated: true)
            } else {
                alert.show(animated: true, vibrate: false)
            }
        }
    }

    // MARK: - Presentation Methods

    /// Presents the authentication interface with normal (app-styled) appearance.
    ///
    /// This method configures the view controller with app branding and presents
    /// it in a navigation controller.
    ///
    /// - Throws: `APWebAuthenticationError.canceled` if view controller is nil
    ///           or no presentation context is available
    private func presentNormalStyle() throws {
        guard let loginViewController = loginViewController else {
            log.error("presentNormalStyle: loginViewController is nil.")
            throw APWebAuthenticationError.canceled
        }

        // Configure view controller
        loginViewController.title = String(
            format: NSLocalizedString("Sign in to %@", comment: ""),
            accountType.description
        )
        loginViewController.progressView.tintColor = UIColor(named: "TintColor")
        loginViewController.statusBarStyle = statusBarStyle

        let navController = UINavigationController(rootViewController: loginViewController)

        // Present from context provider
        guard let vc = presentationContextProvider?.presentationAnchor(for: self), vc.isVisible else {
            log.error("presentNormalStyle: No presentationContextProvider or anchor VC is not visible.")
            throw APWebAuthenticationError.failed(reason: "Could not find a valid view controller to present from.")
        }

        vc.present(navController, animated: true)
    }

    /// Presents the authentication interface with Safari-style appearance.
    ///
    /// This method configures the view controller to look like Safari, including
    /// custom navigation bar styling, toolbar with browser controls, and
    /// form sheet presentation.
    ///
    /// - Throws: `APWebAuthenticationError.canceled` if view controller is nil
    ///           or no presentation context is available
    private func presentSafariStyle() throws {
        guard let loginViewController = loginViewController else {
            log.error("presentSafariStyle: loginViewController is nil.")
            throw APWebAuthenticationError.canceled
        }

        // Configure custom navigation bar view
        let navView = AuthNavBarView()
        navView.hideSecure()
        navView.title = accountType.webAddress

        loginViewController.navigationItem.titleView = navView
        loginViewController.appearanceStyle = .safari
        loginViewController.dismissButtonStyle = .cancel

        let navController = UINavigationController(rootViewController: loginViewController)

        // Apply Safari-like styling based on color scheme
        let isDark = loginViewController.traitCollection.userInterfaceStyle == .dark

        navController.navigationBar.tintColor = isDark ? UIColor(hex: 0x5A91F7) : UIColor(hex: 0x0079FF)
        navController.navigationBar.titleTextAttributes = [
            .foregroundColor: (isDark ? UIColor(hex: 0x5A91F7) : UIColor(hex: 0x0079FF))!
        ]
        navController.navigationBar.barTintColor = isDark ? UIColor(hex: 0x565656) : UIColor(hex: 0xF8F8F8)

        navController.navigationBar.shadowImage = nil
        navController.navigationBar.barStyle = .default
        navController.navigationBar.isTranslucent = false
        navController.modalPresentationStyle = .formSheet

        // Present from context provider
        guard let vc = presentationContextProvider?.presentationAnchor(for: self), vc.isVisible else {
            log.error("presentSafariStyle: No presentationContextProvider or anchor VC is not visible.")
            throw APWebAuthenticationError.failed(reason: "Could not find a valid view controller to present from.")
        }

        vc.present(navController, animated: true)
    }
}

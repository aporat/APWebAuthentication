import UIKit
import WebKit

// MARK: - Navigation Manager

/// Manages navigation bar and toolbar items for web authentication views.
///
/// This class encapsulates all the UI chrome around the web view, including:
/// - Navigation bar buttons (dismiss, refresh, stop, activity indicator)
/// - Toolbar items (back, forward, share, Safari)
/// - Progress bar updates
/// - Appearance configuration (normal vs Safari style)
///
/// **Example Usage:**
/// ```swift
/// let manager = WebAuthNavigationManager(
///     viewController: self,
///     appearanceStyle: .safari
/// )
/// manager.configure()
/// manager.showLoading()
/// ```
@MainActor
public final class WebAuthNavigationManager {
    
    // MARK: - Types
    
    /// Button style for the dismiss/close button
    public enum DismissButtonStyle: Int {
        case done
        case close
        case cancel
    }
    
    // MARK: - Public Properties
    
    /// The appearance style (normal or Safari-like)
    public let appearanceStyle: APWebAuthSession.AppearanceStyle
    
    /// The dismiss button style
    public let dismissButtonStyle: DismissButtonStyle
    
    /// Whether the web view is currently loading
    public private(set) var isLoading = false
    
    // MARK: - Private Properties
    
    private weak var viewController: UIViewController?
    private weak var webView: WKWebView?
    
    // Bar button items
    private var refreshBarButtonItem: UIBarButtonItem!
    private var stopBarButtonItem: UIBarButtonItem!
    private var dismissBarButtonItem: UIBarButtonItem!
    private var activityBarButtonItem: UIBarButtonItem!
    
    // Toolbar items
    private var actionBarBackBarButtonItem: UIBarButtonItem!
    private var actionBarForwardBarButtonItem: UIBarButtonItem!
    private var actionSafariBarButtonItem: UIBarButtonItem!
    private var actionBarButtonItem: UIBarButtonItem!
    
    // Cached bar button item arrays
    private var completedBarButtonItems = [UIBarButtonItem]()
    private var loadingBarButtonItems = [UIBarButtonItem]()
    
    // UI components
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.frame = CGRect(x: 0, y: 0, width: 25, height: 25)
        view.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        view.style = .medium
        view.sizeToFit()
        return view
    }()
    
    // MARK: - Callbacks
    
    /// Called when the dismiss button is tapped
    public var onDismiss: (() -> Void)?
    
    /// Called when the refresh button is tapped
    public var onRefresh: (() -> Void)?
    
    /// Called when the stop button is tapped
    public var onStop: (() -> Void)?
    
    /// Called when the back button is tapped
    public var onBack: (() -> Void)?
    
    /// Called when the forward button is tapped
    public var onForward: (() -> Void)?
    
    /// Called when the Safari button is tapped
    public var onOpenInSafari: (() -> Void)?
    
    /// Called when the share button is tapped
    public var onShare: ((UIBarButtonItem) -> Void)?
    
    /// Called when the text transform button is tapped
    public var onTextTransform: (() -> Void)?
    
    // MARK: - Initialization
    
    /// Creates a new navigation manager.
    ///
    /// - Parameters:
    ///   - viewController: The view controller to manage navigation items for
    ///   - webView: The web view to monitor for navigation state
    ///   - appearanceStyle: The visual appearance style
    ///   - dismissButtonStyle: The dismiss button style
    public init(
        viewController: UIViewController,
        webView: WKWebView,
        appearanceStyle: APWebAuthSession.AppearanceStyle,
        dismissButtonStyle: DismissButtonStyle = .cancel
    ) {
        self.viewController = viewController
        self.webView = webView
        self.appearanceStyle = appearanceStyle
        self.dismissButtonStyle = dismissButtonStyle
    }
    
    // MARK: - Configuration
    
    /// Configures all navigation items and toolbar items.
    ///
    /// Call this method once during view setup to create and configure
    /// all bar button items based on the appearance style.
    public func configure() {
        createBarButtonItems()
        
        if appearanceStyle == .safari {
            configureSafariStyle()
        } else {
            configureNormalStyle()
        }
    }
    
    /// Updates the navigation bar appearance for the given trait collection.
    ///
    /// Call this when the trait collection changes (light/dark mode).
    ///
    /// - Parameter traitCollection: The current trait collection
    public func updateAppearance(for traitCollection: UITraitCollection) {
        guard appearanceStyle == .safari,
              let navigationController = viewController?.navigationController else {
            return
        }
        
        let isDark = traitCollection.userInterfaceStyle == .dark
        
        // Navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = isDark ? UIColor(hex: 0x565656) : UIColor(hex: 0xF8F8F8)
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: (isDark ? UIColor(hex: 0x5A91F7) : UIColor(hex: 0x0079FF))!
        ]
        
        navigationController.navigationBar.standardAppearance = navBarAppearance
        navigationController.navigationBar.scrollEdgeAppearance = navBarAppearance
        navigationController.navigationBar.compactAppearance = navBarAppearance
        navigationController.navigationBar.compactScrollEdgeAppearance = navBarAppearance
        
        navigationController.navigationBar.tintColor = isDark ? UIColor(hex: 0x5A91F7) : UIColor(hex: 0x0079FF)
        navigationController.navigationBar.barTintColor = isDark ? UIColor(hex: 0x565656) : UIColor(hex: 0xF8F8F8)
        
        // Toolbar appearance
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithOpaqueBackground()
        toolbarAppearance.backgroundColor = isDark ? UIColor(hex: 0x565656) : UIColor(hex: 0xF8F8F8)
        
        navigationController.toolbar.standardAppearance = toolbarAppearance
        navigationController.toolbar.scrollEdgeAppearance = toolbarAppearance
        navigationController.toolbar.compactAppearance = toolbarAppearance
        navigationController.toolbar.compactScrollEdgeAppearance = toolbarAppearance
    }
    
    // MARK: - Loading State
    
    /// Shows loading indicators (activity indicator or stop button).
    public func showLoading() {
        isLoading = true
        
        guard let viewController = viewController else { return }
        
        if appearanceStyle == .normal {
            activityIndicator.startAnimating()
            viewController.navigationItem.rightBarButtonItems = [activityBarButtonItem]
        } else {
            viewController.navigationItem.rightBarButtonItems = loadingBarButtonItems
            updateToolbarButtonStates()
        }
    }
    
    /// Hides loading indicators and shows normal controls.
    public func hideLoading() {
        isLoading = false
        
        guard let viewController = viewController else { return }
        
        if appearanceStyle == .normal {
            activityIndicator.stopAnimating()
        }
        
        viewController.navigationItem.rightBarButtonItems = completedBarButtonItems
        updateToolbarButtonStates()
    }
    
    /// Updates the progress bar for Safari-style navigation.
    ///
    /// - Parameter progress: Progress value from 0.0 to 1.0
    public func updateProgress(_ progress: Float) {
        guard appearanceStyle == .safari,
              let navigationController = viewController?.navigationController else {
            return
        }
        
        if progress >= 1.0 {
            navigationController.finishProgress()
        } else {
            navigationController.setProgress(progress, animated: true)
        }
    }
    
    // MARK: - Private Methods - Setup
    
    private func createBarButtonItems() {
        // Dismiss button
        var dismissLabel = NSLocalizedString("Cancel", comment: "")
        if dismissButtonStyle == .close {
            dismissLabel = NSLocalizedString("Close", comment: "")
        } else if dismissButtonStyle == .done {
            dismissLabel = NSLocalizedString("Done", comment: "")
        }
        
        dismissBarButtonItem = UIBarButtonItem(
            title: dismissLabel,
            style: .plain,
            target: self,
            action: #selector(dismissTapped)
        )
        
        // Refresh and stop buttons
        refreshBarButtonItem = createNavBarButton(
            systemName: "arrow.clockwise",
            selector: #selector(refreshTapped)
        )
        stopBarButtonItem = createNavBarButton(
            systemName: "xmark",
            selector: #selector(stopTapped)
        )
        
        // Activity indicator
        activityBarButtonItem = UIBarButtonItem(customView: activityIndicator)
        
        // Toolbar buttons
        actionBarBackBarButtonItem = createToolbarButton(
            systemName: "chevron.left",
            selector: #selector(backTapped)
        )
        actionBarForwardBarButtonItem = createToolbarButton(
            systemName: "chevron.right",
            selector: #selector(forwardTapped)
        )
        actionSafariBarButtonItem = createToolbarButton(
            systemName: "safari",
            selector: #selector(safariTapped)
        )
        actionBarButtonItem = createToolbarButton(
            systemName: "square.and.arrow.up",
            selector: #selector(shareTapped)
        )
    }
    
    private func configureNormalStyle() {
        guard let viewController = viewController else { return }
        
        completedBarButtonItems = [refreshBarButtonItem]
        loadingBarButtonItems = [stopBarButtonItem]
        
        viewController.navigationItem.leftBarButtonItems = [dismissBarButtonItem]
        viewController.navigationItem.rightBarButtonItems = [activityBarButtonItem]
        
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(named: "BarTintColor")
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(named: "TintColor")!
        ]
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(named: "TintColor")!
        ]
        
        dismissBarButtonItem.setTitleTextAttributes([.foregroundColor: UIColor(named: "TintColor")!], for: .normal)
        dismissBarButtonItem.setTitleTextAttributes([.foregroundColor: UIColor(named: "TintColor")!], for: .highlighted)
        
        viewController.navigationController?.navigationBar.standardAppearance = navBarAppearance
        viewController.navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance
        viewController.navigationController?.navigationBar.compactAppearance = navBarAppearance
        viewController.navigationController?.navigationBar.compactScrollEdgeAppearance = navBarAppearance
    }
    
    private func configureSafariStyle() {
        guard let viewController = viewController,
              let navigationController = viewController.navigationController else {
            return
        }
        
        // Text transform button for toolbar
        let textTransformButton = createToolbarButton(
            systemName: "textformat.size",
            selector: #selector(textTransformTapped)
        )
        
        completedBarButtonItems = [
            refreshBarButtonItem,
            UIBarButtonItem.fixedSpace(width: 0),
            textTransformButton
        ]
        loadingBarButtonItems = [
            stopBarButtonItem,
            UIBarButtonItem.fixedSpace(width: 0),
            textTransformButton
        ]
        
        viewController.navigationItem.leftBarButtonItems = [dismissBarButtonItem]
        viewController.navigationItem.rightBarButtonItems = completedBarButtonItems
        
        // Configure toolbar
        viewController.toolbarItems = [
            actionBarBackBarButtonItem,
            UIBarButtonItem.flexibleSpace,
            actionBarForwardBarButtonItem,
            UIBarButtonItem.flexibleSpace,
            UIBarButtonItem.flexibleSpace,
            actionBarButtonItem,
            UIBarButtonItem.flexibleSpace,
            actionSafariBarButtonItem
        ]
        
        navigationController.toolbar.isTranslucent = false
        navigationController.setToolbarHidden(false, animated: false)
        
        if viewController.presentingViewController == nil {
            navigationController.toolbar.barTintColor = navigationController.navigationBar.barTintColor
        } else {
            navigationController.toolbar.barStyle = navigationController.navigationBar.barStyle
        }
        navigationController.toolbar.tintColor = navigationController.navigationBar.tintColor
        
        // Configure navigation bar appearance
        let isDark = navigationController.traitCollection.userInterfaceStyle == .dark
        
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = isDark ? UIColor(hex: 0x565656) : UIColor(hex: 0xF8F8F8)
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        navigationController.navigationBar.standardAppearance = navBarAppearance
        navigationController.navigationBar.scrollEdgeAppearance = navBarAppearance
        navigationController.navigationBar.compactAppearance = navBarAppearance
        navigationController.navigationBar.compactScrollEdgeAppearance = navBarAppearance
        navigationController.navigationBar.isTranslucent = false
        
        // Configure toolbar appearance
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithOpaqueBackground()
        toolbarAppearance.backgroundColor = isDark ? UIColor(hex: 0x565656) : UIColor(hex: 0xF8F8F8)
        
        navigationController.toolbar.standardAppearance = toolbarAppearance
        navigationController.toolbar.scrollEdgeAppearance = toolbarAppearance
        navigationController.toolbar.compactAppearance = toolbarAppearance
        navigationController.toolbar.compactScrollEdgeAppearance = toolbarAppearance
    }
    
    private func updateToolbarButtonStates() {
        guard let webView = webView else { return }
        
        actionBarBackBarButtonItem.isEnabled = webView.canGoBack
        actionBarForwardBarButtonItem.isEnabled = webView.canGoForward
    }
    
    // MARK: - Button Creation
    
    private func createNavBarButton(systemName: String, selector: Selector) -> UIBarButtonItem {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.addTarget(self, action: selector, for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        button.imageView?.contentMode = .scaleAspectFit
        button.tintColor = UIColor.black
        return UIBarButtonItem(customView: button)
    }
    
    private func createToolbarButton(systemName: String, selector: Selector) -> UIBarButtonItem {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.addTarget(self, action: selector, for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 40, height: 30)
        button.imageView?.contentMode = .scaleAspectFit
        button.tintColor = UIColor.black
        return UIBarButtonItem(customView: button)
    }
    
    // MARK: - Actions
    
    @objc private func dismissTapped() {
        onDismiss?()
    }
    
    @objc private func refreshTapped() {
        onRefresh?()
    }
    
    @objc private func stopTapped() {
        onStop?()
    }
    
    @objc private func backTapped() {
        onBack?()
    }
    
    @objc private func forwardTapped() {
        onForward?()
    }
    
    @objc private func safariTapped() {
        onOpenInSafari?()
    }
    
    @objc private func shareTapped(_ sender: UIBarButtonItem) {
        onShare?(sender)
    }
    
    @objc private func textTransformTapped() {
        onTextTransform?()
    }
}

// MARK: - UIBarButtonItem Extensions

private extension UIBarButtonItem {
    /// Creates a fixed-width spacer bar button item.
    static func fixedSpace(width: CGFloat) -> UIBarButtonItem {
        let spacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        spacer.width = width
        return spacer
    }
    
    /// Creates a flexible space bar button item.
    static var flexibleSpace: UIBarButtonItem {
        UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }
}

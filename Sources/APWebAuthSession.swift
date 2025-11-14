import UIKit

extension APWebAuthSession {
    public enum AppearanceStyle: Int {
        case normal
        case safari
    }
}

public protocol APWebAuthenticationPresentationContextProviding: NSObjectProtocol {
    func presentationAnchor(for session: APWebAuthSession) -> UIViewController?
}

@MainActor
public class APWebAuthSession {
    public var statusBarStyle = UIStatusBarStyle.default
    public var appearanceStyle: APWebAuthSession.AppearanceStyle = .normal
    public var loginViewController: WebAuthViewController?
    public weak var presentationContextProvider: APWebAuthenticationPresentationContextProviding?
    
    fileprivate var accountType: AccountType
    
    public init(accountType: AccountType) {
        self.accountType = accountType
    }
    
    @discardableResult
    // REFACTOR: Changed return type from `[String: Any]?` to `[String: String]?`
    // to match the Sendable `CompletionHandler` in `WebAuthViewController`.
    public func start(url URL: URL, callbackURL: URL) async throws(APWebAuthenticationError) -> [String: String]? {
        loginViewController = WebAuthViewController(authURL: URL, redirectURL: callbackURL)
        return try await start()
    }
    
    @discardableResult
    // REFACTOR: Changed return type from `[String: Any]?` to `[String: String]?`
    public func start() async throws(APWebAuthenticationError) -> [String: String]? {
        do {
            if appearanceStyle == .safari {
                let loginRequested = await showLoginPermission()
                guard loginRequested else {
                    throw APWebAuthenticationError.loginCanceled
                }
            }
            
            return try await withCheckedThrowingContinuation { continuation in
                
                guard let loginVC = self.loginViewController else {
                    continuation.resume(throwing: APWebAuthenticationError.loginCanceled)
                    return
                }

                // The completionHandler is already called on the @MainActor,
                // so the extra `Task { @MainActor in ... }` is not needed.
                loginVC.completionHandler = { result in
                    switch result {
                    case .success(let params):
                        continuation.resume(returning: params)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                do {
                    if appearanceStyle == .safari {
                        try self.presentSafariStyle()
                    } else {
                        try self.presentNormalStyle()
                    }
                } catch {
                    // Convert any presentation error into an APWebAuthenticationError
                    let authError = (error as? APWebAuthenticationError) ?? .failed(reason: error.localizedDescription)
                    continuation.resume(throwing: authError)
                }
            }
        } catch {
            // Re-throw the error, ensuring it's always an APWebAuthenticationError
            throw (error as? APWebAuthenticationError) ?? .failed(reason: error.localizedDescription)
        }
    }
    
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
                // Fallback to show on key window
                alert.show(animated: true, vibrate: false)
            }
        }
    }
    
    private func presentNormalStyle() throws {
        guard let loginViewController = loginViewController else {
            throw APWebAuthenticationError.loginCanceled
        }
        
        loginViewController.title = String(format: NSLocalizedString("Sign in to %@", comment: ""), accountType.description)
        loginViewController.progressView.tintColor = UIColor(named: "TintColor")
        loginViewController.statusBarStyle = statusBarStyle
        
        let navController = UINavigationController(rootViewController: loginViewController)
        
        guard let vc = presentationContextProvider?.presentationAnchor(for: self), vc.isVisible else {
            // Handle error: No presentation anchor found or it's not visible
            throw APWebAuthenticationError.failed(reason: "Could not find a valid view controller to present from.")
        }
        
        vc.present(navController, animated: true)
    }
    
    private func presentSafariStyle() throws {
        guard let loginViewController = loginViewController else {
            throw APWebAuthenticationError.loginCanceled
        }
        
        let navView = AuthNavBarView()
        navView.hideSecure()
        navView.title = accountType.webAddress
        
        loginViewController.navigationItem.titleView = navView
        loginViewController.appearanceStyle = .safari
        loginViewController.dismissButtonStyle = .cancel
        
        let navController = UINavigationController(rootViewController: loginViewController)
        
        if loginViewController.traitCollection.userInterfaceStyle == .dark {
            navController.navigationBar.tintColor = UIColor(hex: 0x5A91F7)
            navController.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(hex: 0x5A91F7)!]
            navController.navigationBar.barTintColor = UIColor(hex: 0x565656)
        } else {
            navController.navigationBar.tintColor = UIColor(hex: 0x0079FF)
            navController.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(hex: 0x0079FF)!]
            navController.navigationBar.barTintColor = UIColor(hex: 0xF8F8F8)
        }
        
        navController.navigationBar.shadowImage = nil
        navController.navigationBar.barStyle = .default
        navController.navigationBar.isTranslucent = false
        navController.modalPresentationStyle = .formSheet
        
        guard let vc = presentationContextProvider?.presentationAnchor(for: self), vc.isVisible else {
            // Handle error: No presentation anchor found or it's not visible
            throw APWebAuthenticationError.failed(reason: "Could not find a valid view controller to present from.")
        }
        
        vc.present(navController, animated: true)
    }
}

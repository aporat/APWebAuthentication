import UIKit

extension APWebAuthenticationSession {
    public enum AppearanceStyle: Int {
        case normal
        case safari
    }
}

public protocol APWebAuthenticationPresentationContextProviding: NSObjectProtocol {
    func presentationAnchor(for session: APWebAuthenticationSession) -> UIViewController?
}

@MainActor
public class APWebAuthenticationSession {
    public var statusBarStyle = UIStatusBarStyle.default
    public var appearanceStyle: APWebAuthenticationSession.AppearanceStyle = .normal
    public var loginViewController: BaseAuthViewController?
    public weak var presentationContextProvider: APWebAuthenticationPresentationContextProviding?
    
    fileprivate var accountType: AccountType
    
    public init(accountType: AccountType) {
        self.accountType = accountType
    }
    
    @discardableResult
    public func start(url URL: URL, callbackURL: URL) async throws(APWebAuthenticationError) -> [String: Any]? {
        loginViewController = AuthViewController(authURL: URL, redirectURL: callbackURL)
        return try await start()
    }
    
    @discardableResult
    public func start() async throws(APWebAuthenticationError) -> [String: Any]? {
        do {
            if appearanceStyle == .safari {
                let loginRequested = await showLoginPermission()
                guard loginRequested else {
                    throw APWebAuthenticationError.loginCanceled
                }
            }
            
            return try await withCheckedThrowingContinuation { continuation in
                
                self.loginViewController?.completionHandler = { result in
                    switch result {
                    case .success(let params):
                        continuation.resume(returning: params)
                    case .failure(let error):
                        if let authError = error as? APWebAuthenticationError {
                            continuation.resume(throwing: authError)
                        } else {
                            continuation.resume(throwing: APWebAuthenticationError.failed(reason: error.localizedDescription))
                        }
                    }
                }
                
                do {
                    if appearanceStyle == .safari {
                        try self.presentSafariStyle()
                    } else {
                        try self.presentNormalStyle()
                    }
                } catch {
                    if let authError = error as? APWebAuthenticationError {
                        continuation.resume(throwing: authError)
                    } else {
                        continuation.resume(throwing: APWebAuthenticationError.failed(reason: error.localizedDescription))
                    }
                }
            }
        } catch {
            if let authError = error as? APWebAuthenticationError {
                throw authError
            } else {
                throw APWebAuthenticationError.failed(reason: error.localizedDescription)
            }
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
        
        if let vc = presentationContextProvider?.presentationAnchor(for: self), vc.isVisible {
            vc.present(navController, animated: true)
        }
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
        
        if let vc = presentationContextProvider?.presentationAnchor(for: self), vc.isVisible {
            vc.present(navController, animated: true)
        }
    }
}

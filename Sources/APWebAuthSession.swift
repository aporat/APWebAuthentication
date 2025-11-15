import UIKit
import SwiftyBeaver
import SwifterSwift

extension APWebAuthSession {
    public enum AppearanceStyle: Int {
        case normal
        case safari
    }
}

public protocol APWebAuthenticationPresentationContextProviding: NSObjectProtocol {
    func presentationAnchor(for session: APWebAuthSession) -> UIViewController?
}

public let log = SwiftyBeaver.self

@MainActor
public class APWebAuthSession {
    public var statusBarStyle = UIStatusBarStyle.default
    public var appearanceStyle: APWebAuthSession.AppearanceStyle = .normal
    public var loginViewController: WebAuthViewController?
    public weak var presentationContextProvider: APWebAuthenticationPresentationContextProviding?
    
    fileprivate var accountType: AccountType
    
    public init(accountType: AccountType) {
        self.accountType = accountType
        log.debug("APWebAuthSession init for \(accountType.description)")
    }
    
    @discardableResult
    public func start(url URL: URL, callbackURL: URL) async throws(APWebAuthenticationError) -> [String: String]? {
        log.debug("APWebAuthSession start(url:callbackURL:) called.")
        loginViewController = WebAuthViewController(authURL: URL, redirectURL: callbackURL)
        return try await start()
    }
    
    @discardableResult
       public func start() async throws(APWebAuthenticationError) -> [String: String]? {
           log.debug("APWebAuthSession start() initiated.")
           do {
               if appearanceStyle == .safari {
                   log.debug("Safari style. Awaiting showLoginPermission...")
                   let loginRequested = await showLoginPermission()
                   guard loginRequested else {
                       log.warning("Login permission denied by user.")
                       throw APWebAuthenticationError.canceled
                   }
               }
               
               return try await withCheckedThrowingContinuation { (continuation: (CheckedContinuation<[String: String]?, Error>)) in
                   
                   log.debug("withCheckedThrowingContinuation started. Awaiting completionHandler...")
                   
                   guard let loginVC = self.loginViewController else {
                       log.error("loginViewController is nil before completionHandler can be set.")
                       continuation.resume(throwing: APWebAuthenticationError.canceled)
                       return
                   }

                   loginVC.completionHandler = { [weak self] result in
                       
                       log.debug("completionHandler fired with result: \(result)")
                       
                       switch result {
                       case .success(let params):
                           log.info("completionHandler: Success. Resuming continuation.")
                           continuation.resume(returning: params)
                       case .failure(let error):
                           log.error("completionHandler: Failure. Resuming with error: \(error.localizedDescription)")
                           continuation.resume(throwing: error)
                       }
                       
                       guard let self = self else {
                           log.warning("APWebAuthSession was nil inside completionHandler.")
                           return
                       }
                       
                       log.debug("Dismissing loginViewController and nilling reference.")
                       self.loginViewController?.dismiss(animated: true) {
                           self.loginViewController = nil // Break the cycle
                       }
                   }
                   
                   do {
                       if appearanceStyle == .safari {
                           log.info("Presenting Safari style login.")
                           try self.presentSafariStyle()
                       } else {
                           log.info("Presenting Normal style login.")
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
    
    private func showLoginPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            let title = String(format: NSLocalizedString("“%@” Wants to Use “%@” to Sign In", comment: ""), UIApplication.shared.shortAppName, self.accountType.webAddress)
            let message = NSLocalizedString("This allows the app and website to share information about you.", comment: "")
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            alert.addAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                log.debug("Login permission: User tapped Cancel.")
                continuation.resume(returning: false)
            }
            alert.addAction(title: NSLocalizedString("Continue", comment: ""), style: .default) { _ in
                log.debug("Login permission: User tapped Continue.")
                continuation.resume(returning: true)
            }
            alert.preferredAction = alert.actions.last
            
            if let vc = self.presentationContextProvider?.presentationAnchor(for: self), vc.isVisible {
                vc.present(alert, animated: true)
            } else {
                log.warning("No presentation anchor found for login permission. Using fallback.")
                alert.show(animated: true, vibrate: false)
            }
        }
    }
    
    private func presentNormalStyle() throws {
        guard let loginViewController = loginViewController else {
            log.error("presentNormalStyle: loginViewController is nil.")
            throw APWebAuthenticationError.canceled
        }
        
        loginViewController.title = String(format: NSLocalizedString("Sign in to %@", comment: ""), accountType.description)
        loginViewController.progressView.tintColor = UIColor(named: "TintColor")
        loginViewController.statusBarStyle = statusBarStyle
        
        let navController = UINavigationController(rootViewController: loginViewController)
        
        guard let vc = presentationContextProvider?.presentationAnchor(for: self), vc.isVisible else {
            log.error("presentNormalStyle: No presentationContextProvider or anchor VC is not visible.")
            throw APWebAuthenticationError.failed(reason: "Could not find a valid view controller to present from.")
        }
        
        vc.present(navController, animated: true)
    }
    
    private func presentSafariStyle() throws {
        guard let loginViewController = loginViewController else {
            log.error("presentSafariStyle: loginViewController is nil.")
            throw APWebAuthenticationError.canceled
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
            log.error("presentSafariStyle: No presentationContextProvider or anchor VC is not visible.")
            throw APWebAuthenticationError.failed(reason: "Could not find a valid view controller to present from.")
        }
        
        vc.present(navController, animated: true)
    }
}

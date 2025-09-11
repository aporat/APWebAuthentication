import UIKit

extension APWebAuthenticationSession {
    public enum AppearanceStyle: Int {
        case normal
        case safari
    }

    public typealias CompletionHandler = (Result<[String: Any]?, APWebAuthenticationError>) -> Void
}

public protocol APWebAuthenticationPresentationContextProviding: NSObjectProtocol {
    func presentationAnchor(for session: APWebAuthenticationSession) -> UIViewController?
}

@MainActor
public class APWebAuthenticationSession {
    public var statusBarStyle = UIStatusBarStyle.default
    public var appearanceStyle: APWebAuthenticationSession.AppearanceStyle = .normal
    public var loginViewController: BaseAuthViewController?
    public var completionHandler: CompletionHandler?
    public weak var presentationContextProvider: APWebAuthenticationPresentationContextProviding?

    fileprivate var accountType: AccountType

    public init(accountType: AccountType, completionHandler: @escaping APWebAuthenticationSession.CompletionHandler) {
        self.accountType = accountType
        self.completionHandler = completionHandler
    }

    @discardableResult
    public func start(url URL: URL, callbackURL: URL) -> Bool {
        loginViewController = AuthViewController(authURL: URL, redirectURL: callbackURL)

        return start()
    }

    @discardableResult
    public func start() -> Bool {
        loginViewController?.completionHandler = completionHandler

        if appearanceStyle == .safari {
            showLoginPermission { loginRequested in

                if loginRequested {
                    self.presentSafariStyle()
                } else {
                    self.completionHandler?(.failure(APWebAuthenticationError.loginCanceled))
                }
            }
        } else {
            presentNormalStyle()
        }

        return true
    }

    private func showLoginPermission(_ completion: @escaping (_ loginRequested: Bool) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            let actionSheetController = UIAlertController(title: String(format: NSLocalizedString("“%@” Wants to Use “%@” to Sign In", comment: ""), UIApplication.shared.shortAppName, self.accountType.webAddress), message: NSLocalizedString("This allows the app and website to share information about you.", comment: ""), preferredStyle: .alert)

            actionSheetController.addAction(title: NSLocalizedString("Cancel", comment: ""), style: .default) { _ in
                completion(false)
            }

            actionSheetController.addAction(title: NSLocalizedString("Continue", comment: ""), style: .default) { _ in
                completion(true)
            }

            actionSheetController.preferredAction = actionSheetController.actions[actionSheetController.actions.count - 1]

            if let vc = self.presentationContextProvider?.presentationAnchor(for: self), vc.isVisible {
                vc.present(actionSheetController, animated: true)
            } else {
                actionSheetController.show(animated: true, vibrate: false)
            }
        }
    }

    private func presentNormalStyle(_ completion: (() -> Void)? = nil) {
        guard let loginViewController = loginViewController else {
            completionHandler?(.failure(APWebAuthenticationError.loginCanceled))
            return
        }

        loginViewController.title = String(format: NSLocalizedString("Sign in to %@", comment: ""), accountType.description)
        loginViewController.progressView.tintColor = UIColor(named: "TintColor")
        loginViewController.statusBarStyle = statusBarStyle

        let navController = UINavigationController(rootViewController: loginViewController)

        if let vc = presentationContextProvider?.presentationAnchor(for: self), vc.isVisible {
            vc.present(navController, animated: true, completion: completion)
        }
    }

    private func presentSafariStyle(_ completion: (() -> Void)? = nil) {
        guard let loginViewController = loginViewController else {
            completionHandler?(.failure(APWebAuthenticationError.loginCanceled))
            return
        }

        let navView = AuthNavBarView()
        navView.hideSecure()
        navView.titleLabel.text = accountType.webAddress

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
            vc.present(navController, animated: true, completion: completion)
        }
    }
}

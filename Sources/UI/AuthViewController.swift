import Foundation
import JGProgressHUD
import WebKit

open class AuthViewController: BaseAuthViewController {
    // MARK: - UI Elements

    fileprivate lazy var loginHUD: JGProgressHUD = {
        let view = JGProgressHUD(style: .dark)
        return view
    }()

    // MARK: - Data

    public var existingSessionId: String?

    // MARK: - UIViewController

    override open func viewDidLoad() {
        super.viewDidLoad()

        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in

            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {
                self.loadRequest()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            if let navBar = self.navigationItem.titleView as? AuthNavBarView {
                navBar.showSecure()
            }
        }
    }

    // MARK: - WKNavigationDelegate

    open func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if let urlString = navigationAction.request.url?.absoluteString, let currentRedirectURL = redirectURL?.absoluteString, !urlString.isEmpty {
            
            if urlString.hasPrefix(currentRedirectURL) {
                let result = navigationAction.request.url?.getResponse()
                if case let .success(params) = result {
                    DispatchQueue.main.async {
                        self.dismiss(animated: true) {
                            self.completionHandler?(.success(params))
                            self.completionHandler = nil
                        }
                    }
                } else if case let .failure(error) = result {
                    DispatchQueue.main.async {
                        self.dismiss(animated: true) {
                            self.completionHandler?(.failure(error))
                            self.completionHandler = nil
                        }
                    }
                }

                decisionHandler(.cancel)
                return
            }
        }

        decisionHandler(.allow)
    }

    // MARK: - UI Loading

    public func showHUD() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            self.loginHUD.show(in: self.view)
        }
    }

    public func hideHUD() {
        DispatchQueue.main.async { [weak self] in
            self?.loginHUD.dismiss()
        }
    }
}

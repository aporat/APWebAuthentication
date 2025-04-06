import WebKit

open class WebViewController: BaseAuthViewController {
    // MARK: - UIViewController

    override open func viewDidLoad() {
        super.viewDidLoad()

        webView.isOpaque = false
        view.backgroundColor = UIColor.systemGroupedBackground

        loadRequest()
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
}

import WebKit

// MARK: - Weak Script Message Handler

/// Forwards script messages to a weakly-held target.
///
/// `WKUserContentController` retains its message handlers. Registering the
/// view controller directly makes the cycle
/// `controller -> configuration -> userContentController -> controller`,
/// so `deinit` never runs and the whole web view leaks. Registering this
/// proxy instead leaves the controller free to deallocate.
@MainActor
public final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {

    private weak var target: (any WKScriptMessageHandler)?

    public init(target: any WKScriptMessageHandler) {
        self.target = target
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

@testable import APWebAuthentication
import UIKit
import XCTest

@MainActor
final class WebAuthViewControllerCompletionTests: XCTestCase {

    private func makeController() -> WebAuthViewController {
        WebAuthViewController(
            authURL: URL(string: "https://example.com/auth"),
            redirectURL: URL(string: "myapp://callback")
        )
    }

    func testComplete_deliversResultOnce() {
        let controller = makeController()
        var received: [Result<(URL, [HTTPCookie]), APWebAuthenticationError>] = []
        controller.completionHandler = { received.append($0) }

        controller.complete(with: .failure(.canceled))
        controller.complete(with: .failure(.timeout))

        XCTAssertEqual(received.count, 1)
        guard case .failure(.canceled) = received[0] else {
            return XCTFail("expected the first result, got \(received[0])")
        }
        XCTAssertNil(controller.completionHandler)
    }

    func testComplete_withoutHandler_doesNotCrash() {
        let controller = makeController()

        // A page presented without a handler (terms, FAQ) still has to be
        // closable, so this must run the dismissal path rather than bail out.
        controller.complete(with: .failure(.canceled))

        XCTAssertNil(controller.completionHandler)
    }

    /// Stands in for a presented controller.
    ///
    /// An earlier version of this test presented for real, against a `UIWindow`
    /// it made key. That can never pass here: the test bundle has no host app,
    /// so there is no `UIApplication` ("This process does not have a
    /// UIApplication object and will not receive events!") and the window
    /// belongs to no scene, leaving UIKit unable to finish a dismissal
    /// transition. `presentingViewController` stayed set forever and the test
    /// failed on every run from the commit that added it.
    ///
    /// Stubbing the two things `complete(with:)` actually consults keeps the
    /// subject our own branch — is the dismissal path taken when there is no
    /// handler to report to? — instead of UIKit's transition machinery.
    private final class PresentedControllerStub: WebAuthViewController {

        var stubbedPresentingViewController: UIViewController?
        private(set) var dismissCount = 0

        override var presentingViewController: UIViewController? {
            stubbedPresentingViewController
        }

        override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
            dismissCount += 1
            completion?()
        }
    }

    private func makePresentedStub() -> PresentedControllerStub {
        let controller = PresentedControllerStub(
            authURL: URL(string: "https://example.com/auth"),
            redirectURL: URL(string: "myapp://callback")
        )
        controller.stubbedPresentingViewController = UIViewController()
        return controller
    }

    func testComplete_whenPresented_dismissesWithoutHandler() {
        let controller = makePresentedStub()

        // No handler set: a page opened without one (terms, FAQ) still has to
        // come down rather than bail out of `complete(with:)` early.
        controller.complete(with: .failure(.canceled))

        XCTAssertEqual(controller.dismissCount, 1)
    }

    func testComplete_whenPresented_dismissesBeforeDeliveringResult() {
        let controller = makePresentedStub()
        var received: [Result<(URL, [HTTPCookie]), APWebAuthenticationError>] = []
        controller.completionHandler = { received.append($0) }

        controller.complete(with: .failure(.canceled))

        XCTAssertEqual(controller.dismissCount, 1)
        XCTAssertEqual(received.count, 1)
        XCTAssertNil(controller.completionHandler)
    }

    func testComplete_whenPresented_dismissesOnlyOnceForRepeatedCalls() {
        let controller = makePresentedStub()
        var received: [Result<(URL, [HTTPCookie]), APWebAuthenticationError>] = []
        controller.completionHandler = { received.append($0) }

        controller.complete(with: .failure(.canceled))
        controller.complete(with: .failure(.timeout))

        // The sheet comes down for each call — a second `complete` on a still
        // presented controller has to be able to close it — but the result is
        // reported once, to the handler claimed by the first caller.
        XCTAssertEqual(received.count, 1)
        guard case .failure(.canceled) = received[0] else {
            return XCTFail("expected the first result, got \(received[0])")
        }
    }

    func testComplete_whenNotPresented_deliversSynchronously() {
        let controller = makeController()
        var delivered = false
        controller.completionHandler = { _ in delivered = true }

        controller.complete(with: .failure(.canceled))

        XCTAssertTrue(delivered, "an unpresented controller has nothing to dismiss and must not wait on UIKit")
    }
}

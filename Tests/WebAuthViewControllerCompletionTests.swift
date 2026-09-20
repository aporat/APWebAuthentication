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

    func testComplete_whenPresented_dismissesWithoutHandler() async {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIViewController()
        window.rootViewController = host
        window.makeKeyAndVisible()
        let controller = makeController()
        host.present(controller, animated: false)
        XCTAssertNotNil(controller.presentingViewController)

        controller.complete(with: .failure(.canceled))

        // Poll rather than sampling once at a fixed deadline. Presenting this
        // controller builds a WKWebView, and on a loaded CI machine its web
        // content and GPU processes have taken 20s each to launch — with the
        // render server that starved, an animated dismissal overruns any
        // deadline short enough to be worth waiting for. Sampling once meant
        // the difference between pass and fail was machine load, not
        // behaviour. Awaiting here yields the main actor so UIKit can drive
        // the animation between checks.
        let deadline = Date().addingTimeInterval(30)
        while controller.presentingViewController != nil, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }

        XCTAssertNil(controller.presentingViewController)
    }

    func testComplete_whenNotPresented_deliversSynchronously() {
        let controller = makeController()
        var delivered = false
        controller.completionHandler = { _ in delivered = true }

        controller.complete(with: .failure(.canceled))

        XCTAssertTrue(delivered, "an unpresented controller has nothing to dismiss and must not wait on UIKit")
    }
}

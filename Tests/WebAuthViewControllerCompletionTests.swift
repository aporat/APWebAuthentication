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

    func testComplete_whenPresented_dismissesWithoutHandler() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIViewController()
        window.rootViewController = host
        window.makeKeyAndVisible()
        let controller = makeController()
        host.present(controller, animated: false)
        XCTAssertNotNil(controller.presentingViewController)

        controller.complete(with: .failure(.canceled))

        let dismissed = expectation(description: "dismissed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if controller.presentingViewController == nil { dismissed.fulfill() }
        }
        wait(for: [dismissed], timeout: 3)
    }

    func testComplete_whenNotPresented_deliversSynchronously() {
        let controller = makeController()
        var delivered = false
        controller.completionHandler = { _ in delivered = true }

        controller.complete(with: .failure(.canceled))

        XCTAssertTrue(delivered, "an unpresented controller has nothing to dismiss and must not wait on UIKit")
    }
}

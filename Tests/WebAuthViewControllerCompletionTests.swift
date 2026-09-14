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

    func testComplete_withoutHandler_isNoOp() {
        let controller = makeController()

        controller.complete(with: .failure(.canceled))   // must not crash or throw

        XCTAssertNil(controller.completionHandler)
    }

    func testComplete_whenNotPresented_deliversSynchronously() {
        let controller = makeController()
        var delivered = false
        controller.completionHandler = { _ in delivered = true }

        controller.complete(with: .failure(.canceled))

        XCTAssertTrue(delivered, "an unpresented controller has nothing to dismiss and must not wait on UIKit")
    }
}

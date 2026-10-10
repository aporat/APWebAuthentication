@testable import APWebAuthentication
import UIKit
import XCTest

/// `start()` must resume its caller exactly once, whatever path ends the flow.
@MainActor
final class StartCompletionTests: XCTestCase {

    // MARK: - AuthSessionContinuation

    func testContinuation_resumesCanceledWhenReleasedUnresolved() async {
        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, [HTTPCookie]), Error>) in
                // Simulates the login controller (and its handler) going away
                // without ever reporting a result.
                _ = AuthSessionContinuation(continuation)
            }
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertEqual(error as? APWebAuthenticationError, .canceled)
        }
    }

    func testContinuation_resumesOnlyOnce() async throws {
        let url = URL(string: "myapp://callback?code=1")!
        var results: [Bool] = []
        let value = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, [HTTPCookie]), Error>) in
            let pending = AuthSessionContinuation(continuation)
            results.append(pending.resume(with: .success((url, []))))
            results.append(pending.resume(with: .failure(.timeout)))
        }
        XCTAssertEqual(value.0, url)
        XCTAssertEqual(results, [true, false])
    }

    // MARK: - WebAuthViewController

    private final class DismissedControllerStub: WebAuthViewController {
        var stubbedIsBeingDismissed = false
        override var isBeingDismissed: Bool { stubbedIsBeingDismissed }
    }

    private func makeDismissedStub() -> DismissedControllerStub {
        DismissedControllerStub(
            authURL: URL(string: "https://example.com/auth"),
            redirectURL: URL(string: "myapp://callback")
        )
    }

    func testWebAuth_programmaticDismissal_reportsCanceled() {
        let controller = makeDismissedStub()
        var received: [Result<(URL, [HTTPCookie]), APWebAuthenticationError>] = []
        controller.completionHandler = { received.append($0) }

        controller.stubbedIsBeingDismissed = true
        controller.viewDidDisappear(false)
        controller.viewDidDisappear(false)

        XCTAssertEqual(received.count, 1)
        guard case .failure(.canceled) = received.first else {
            return XCTFail("expected cancellation, got \(String(describing: received.first))")
        }
        XCTAssertNil(controller.completionHandler)
    }

    func testWebAuth_disappearingWithoutDismissal_keepsFlowPending() {
        let controller = makeDismissedStub()
        var received = 0
        controller.completionHandler = { _ in received += 1 }

        // Covered by another full-screen controller: not leaving, still pending.
        controller.viewDidDisappear(false)

        XCTAssertEqual(received, 0)
        XCTAssertNotNil(controller.completionHandler)
    }

    func testWebAuth_completionBeforeDismissal_isNotReportedTwice() {
        let controller = makeDismissedStub()
        var received: [Result<(URL, [HTTPCookie]), APWebAuthenticationError>] = []
        controller.completionHandler = { received.append($0) }

        controller.complete(with: .failure(.timeout))
        controller.stubbedIsBeingDismissed = true
        controller.viewDidDisappear(false)

        XCTAssertEqual(received.count, 1)
        guard case .failure(.timeout) = received.first else {
            return XCTFail("expected the completion result, got \(String(describing: received.first))")
        }
    }

    // MARK: - APWebAuthSession

    func testSession_startWithoutLoginController_throwsCanceled() async {
        let session = APWebAuthSession(accountType: AccountStore.github)
        do {
            try await session.start()
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error, .canceled)
        }
    }

    func testSession_failedStartDoesNotBlockTheNextOne() async {
        let session = APWebAuthSession(accountType: AccountStore.github)

        for _ in 0..<2 {
            session.loginViewController = WebAuthViewController(
                authURL: URL(string: "https://example.com/auth"),
                redirectURL: URL(string: "myapp://callback")
            )
            do {
                try await session.start()
                XCTFail("Expected failure: there is nothing to present from")
            } catch {
                guard case .failed(let reason, _) = error else { return XCTFail("Unexpected error \(error)") }
                XCTAssertFalse(reason?.contains("already in progress") ?? false)
            }
        }
    }

    // MARK: - WebTokenInterceptorViewController

    func testInterceptor_secondStartWhilePending_throwsAndFirstStillResolves() async throws {
        let controller = WebTokenInterceptorViewController(
            configuration: WebTokenInterceptorConfiguration(url: URL(string: "about:blank")!, targetURL: nil)
        )

        let first = Task { @MainActor () -> APWebAuthenticationError? in
            do {
                try await controller.start()
                return nil
            } catch {
                return error
            }
        }

        for _ in 0..<100 where !controller.isAwaitingStart {
            await Task.yield()
        }
        XCTAssertTrue(controller.isAwaitingStart)

        do {
            try await controller.start()
            XCTFail("A second start() while one is pending must throw")
        } catch {
            guard case .failed = error else { return XCTFail("Unexpected error \(error)") }
        }
        XCTAssertTrue(controller.isAwaitingStart, "The first caller's continuation must survive")

        controller.stopLoading()
        let firstError = await first.value
        XCTAssertEqual(firstError, .canceled)

        // A finished flow reports its outcome instead of silently succeeding.
        do {
            try await controller.start()
            XCTFail("Expected the original cancellation")
        } catch {
            XCTAssertEqual(error, .canceled)
        }
    }
}

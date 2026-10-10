@testable import APWebAuthentication
import WebKit
import XCTest

/// Message handling of `WebTokenInterceptorViewController`: parsing what the
/// injected XHR hook posts, deciding whether to intercept, handing the
/// request (and its tokens) to the delegate, and resolving `start()`.
@MainActor
final class WebTokenInterceptorTests: XCTestCase {

    private static let target = URL(string: "https://api.example.com/v1/token")!

    @MainActor
    private final class Recorder: WebTokenInterceptorDelegate {
        private(set) var intercepted: [InterceptedRequest] = []

        func webTokenInterceptor(_ controller: WebTokenInterceptorViewController, didIntercept request: InterceptedRequest) async {
            intercepted.append(request)
        }
    }

    private func makeController(
        targetURL: URL? = WebTokenInterceptorTests.target,
        timeout: TimeInterval = 60
    ) -> WebTokenInterceptorViewController {
        WebTokenInterceptorViewController(
            configuration: WebTokenInterceptorConfiguration(
                url: URL(string: "about:blank")!,
                targetURL: targetURL,
                timeout: timeout
            )
        )
    }

    private func messageBody(
        responseURL: Any = "https://api.example.com/v1/token",
        status: Any? = 200,
        requestHeaders: Any? = ["Authorization": "Bearer abc123", "X-CSRF-Token": "csrf-1"],
        responseHeaders: Any? = "content-type: application/json\r\nset-cookie: sid=xyz\r\n"
    ) -> [String: Any] {
        var body: [String: Any] = ["responseURL": responseURL]
        if let status { body["status"] = status }
        if let requestHeaders { body["requestHeaders"] = requestHeaders }
        if let responseHeaders { body["responseHeaders"] = responseHeaders }
        return body
    }

    /// Starts the flow and waits until `start()` is suspended on its continuation.
    private func startPending(_ controller: WebTokenInterceptorViewController) async -> Task<APWebAuthenticationError?, Never> {
        let task = Task { @MainActor () -> APWebAuthenticationError? in
            do throws(APWebAuthenticationError) {
                try await controller.start()
                return nil
            } catch {
                return error
            }
        }
        for _ in 0..<100 where !controller.isAwaitingStart {
            await Task.yield()
        }
        XCTAssertTrue(controller.isAwaitingStart, "start() should be pending")
        return task
    }

    // MARK: - Message body parsing

    func testParse_fullBody() throws {
        let request = try XCTUnwrap(WebTokenInterceptorViewController.interceptedRequest(
            fromMessageBody: messageBody(),
            targetURL: Self.target
        ))

        XCTAssertEqual(request.responseURL, Self.target)
        XCTAssertEqual(request.targetURL, Self.target)
        XCTAssertEqual(request.statusCode, 200)
        XCTAssertEqual(request.requestHeaders["Authorization"], "Bearer abc123")
        XCTAssertEqual(request.requestHeaders["X-CSRF-Token"], "csrf-1")
        XCTAssertEqual(request.responseHeaders["content-type"], "application/json")
        XCTAssertEqual(request.responseHeaders["set-cookie"], "sid=xyz")
    }

    func testParse_optionalFieldsDefault() throws {
        let request = try XCTUnwrap(WebTokenInterceptorViewController.interceptedRequest(
            fromMessageBody: messageBody(status: nil, requestHeaders: nil, responseHeaders: nil),
            targetURL: nil
        ))

        XCTAssertEqual(request.statusCode, 0)
        XCTAssertEqual(request.requestHeaders, [:])
        XCTAssertEqual(request.responseHeaders, [:])
        XCTAssertNil(request.targetURL)
    }

    func testParse_wrongTypesAreTolerated() throws {
        let request = try XCTUnwrap(WebTokenInterceptorViewController.interceptedRequest(
            fromMessageBody: messageBody(status: "200", requestHeaders: ["a", "b"], responseHeaders: 42),
            targetURL: nil
        ))

        XCTAssertEqual(request.statusCode, 0, "A non-numeric status is not trusted")
        XCTAssertEqual(request.requestHeaders, [:])
        XCTAssertEqual(request.responseHeaders, [:])
    }

    func testParse_rejectsMalformedBodies() {
        let malformed: [Any] = [
            "not a dictionary",
            42,
            ["status": 200],                       // no responseURL
            ["responseURL": 123],                  // not a string
            ["responseURL": ""]                    // not a URL
        ]
        for body in malformed {
            XCTAssertNil(
                WebTokenInterceptorViewController.interceptedRequest(fromMessageBody: body, targetURL: Self.target),
                "\(body) should be rejected"
            )
        }
    }

    // MARK: - Target URL matching

    func testShouldIntercept_matchesTargetAndExtensionsOfIt() {
        let controller = makeController()

        XCTAssertTrue(controller.shouldIntercept(responseURL: Self.target))
        XCTAssertTrue(controller.shouldIntercept(responseURL: URL(string: "https://api.example.com/v1/token?grant=1")!))
        XCTAssertFalse(controller.shouldIntercept(responseURL: URL(string: "https://api.example.com/v1/profile")!))
        XCTAssertFalse(controller.shouldIntercept(responseURL: URL(string: "https://other.example.com/v1/token")!))
        // Not asserted: a URL that merely *contains* the target elsewhere
        // (e.g. in a query string) also matches today. That is the known
        // substring-matching weakness, which this change does not alter.
    }

    func testShouldIntercept_withoutTargetNeverMatches() {
        let controller = makeController(targetURL: nil)
        XCTAssertFalse(controller.shouldIntercept(responseURL: Self.target))
    }

    func testHandleMessage_ignoresMalformedAndNonMatchingBodies() async {
        let controller = makeController()
        let recorder = Recorder()
        controller.delegate = recorder

        XCTAssertNil(controller.handleScriptMessageBody("garbage"))
        XCTAssertNil(controller.handleScriptMessageBody(messageBody(responseURL: "https://api.example.com/v1/profile")))
        await Task.yield()

        XCTAssertTrue(recorder.intercepted.isEmpty)
        XCTAssertFalse(controller.isFinished)
    }

    // MARK: - Interception resolves start()

    func testMatchingMessage_deliversTokensAndResolvesStart() async throws {
        let controller = makeController()
        let recorder = Recorder()
        controller.delegate = recorder
        let pending = await startPending(controller)

        // A non-matching XHR first: start() must stay pending.
        XCTAssertNil(controller.handleScriptMessageBody(messageBody(responseURL: "https://api.example.com/v1/profile")))
        await Task.yield()
        XCTAssertTrue(controller.isAwaitingStart)

        let handled = controller.handleScriptMessageBody(messageBody())
        XCTAssertNotNil(handled)

        let error = await pending.value
        XCTAssertNil(error, "start() returns normally once the target is intercepted")
        XCTAssertTrue(controller.isFinished)
        XCTAssertFalse(controller.isAwaitingStart)

        let intercepted = try XCTUnwrap(recorder.intercepted.first)
        XCTAssertEqual(recorder.intercepted.count, 1)
        XCTAssertEqual(intercepted.requestHeaders["Authorization"], "Bearer abc123")
        XCTAssertEqual(intercepted.responseHeaders["set-cookie"], "sid=xyz")

        // Later matching messages are ignored once the flow has finished.
        controller.handleScriptMessageBody(messageBody())
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(recorder.intercepted.count, 1)
    }

    // MARK: - Error paths

    func testProvisionalNavigationFailure_failsStartWithConnectionError() async {
        let controller = makeController()
        let pending = await startPending(controller)

        controller.webView(
            controller.webView,
            didFailProvisionalNavigation: nil,
            withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost)
        )

        let error = await pending.value
        guard case .some(.connectionError) = error else {
            return XCTFail("expected connectionError, got \(String(describing: error))")
        }
        XCTAssertTrue(controller.isFinished)
    }

    func testCancelledNavigation_isIgnored() async {
        let controller = makeController()
        let pending = await startPending(controller)

        controller.webView(
            controller.webView,
            didFail: nil,
            withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        )
        await Task.yield()
        XCTAssertTrue(controller.isAwaitingStart, "A superseded navigation is not a failure")

        controller.stopLoading()
        let error = await pending.value
        XCTAssertEqual(error, .canceled)
    }

    func testNonInteractiveTimeout_failsStartWithTimeout() async {
        let controller = makeController(timeout: 0.2)
        let pending = await startPending(controller)

        controller.webView(controller.webView, didFinish: nil)

        let error = await pending.value
        XCTAssertEqual(error, .timeout)
    }

    func testInterceptBeforeTimeout_winsAndTimeoutIsIgnored() async throws {
        let controller = makeController(timeout: 0.3)
        let recorder = Recorder()
        controller.delegate = recorder
        let pending = await startPending(controller)

        controller.webView(controller.webView, didFinish: nil)
        controller.handleScriptMessageBody(messageBody())

        let error = await pending.value
        XCTAssertNil(error)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(recorder.intercepted.count, 1)
        XCTAssertTrue(controller.isFinished)
    }
}

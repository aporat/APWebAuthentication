import Alamofire
@testable import APWebAuthentication
import XCTest

/// `cancelAllRequests()` used to be a one-way door: it set the retrier's own
/// `isReloadingCancelled` flag, but `AuthClient.isReloadingCancelled` was
/// separate storage, so clearing the client's flag before the next reload left
/// the retrier latched off for the rest of the client's life.
@MainActor
final class AuthClientCancellationTests: XCTestCase {

    /// Thread-safe hit counter shared with the `@Sendable` mock handler.
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func increment() { lock.withLock { value += 1 } }
        var count: Int { lock.withLock { value } }
    }

    private var client: MockTransportClient!

    override func setUp() async throws {
        try await super.setUp()
        client = MockTransportClient()
    }

    override func tearDown() async throws {
        MockURLProtocol.handler = nil
        try await super.tearDown()
    }

    @discardableResult
    private func installServerErrorHandler() -> Counter {
        let hits = Counter()
        MockURLProtocol.handler = { request in
            hits.increment()
            return MockURLProtocol.response(for: request, status: 503)
        }
        return hits
    }

    func testCancelAllRequests_propagatesToRetrier() {
        client.cancelAllRequests()

        XCTAssertTrue(client.isReloadingCancelled)
        XCTAssertTrue(client.transientNetworkRetrier.isReloadingCancelled)
    }

    func testClearingFlag_reArmsRetrier() {
        client.cancelAllRequests()

        client.isReloadingCancelled = false

        XCTAssertFalse(client.transientNetworkRetrier.isReloadingCancelled)
    }

    func testRetriesResumeAfterCancelThenReset() async {
        let hits = installServerErrorHandler()

        client.cancelAllRequests()
        client.isReloadingCancelled = false

        _ = try? await client.request("/feed")

        // Once re-armed, a 503 on a GET is retried exactly once, as it would be
        // on a client that had never been cancelled.
        XCTAssertEqual(hits.count, 2)
    }

    func testRetriesSuppressedWhileCancelled() async {
        let hits = installServerErrorHandler()

        client.cancelAllRequests()

        _ = try? await client.request("/feed")

        XCTAssertEqual(hits.count, 1)
    }
}

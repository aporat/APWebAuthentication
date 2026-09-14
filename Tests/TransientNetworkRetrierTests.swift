import Alamofire
@testable import APWebAuthentication
import XCTest

/// Drives real requests through the mock transport so the retrier is
/// exercised exactly as Alamofire invokes it, not in isolation.
@MainActor
final class TransientNetworkRetrierTests: XCTestCase {

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

    private func installServerErrorHandler() -> Counter {
        let hits = Counter()
        MockURLProtocol.handler = { request in
            hits.increment()
            return MockURLProtocol.response(for: request, status: 503)
        }
        return hits
    }

    func testGETOn503_isRetriedOnce() async {
        let hits = installServerErrorHandler()

        _ = try? await client.request("/feed")

        XCTAssertEqual(hits.count, 2)
    }

    func testDELETEOn503_isRetriedOnce() async {
        let hits = installServerErrorHandler()

        _ = try? await client.request("/posts/1", method: .delete)

        XCTAssertEqual(hits.count, 2)
    }

    func testPOSTOn503_isNotRetried() async {
        let hits = installServerErrorHandler()

        _ = try? await client.request("/posts", method: .post, parameters: ["text": "hi"])

        XCTAssertEqual(hits.count, 1)
    }

    func testPATCHOn503_isNotRetried() async {
        let hits = installServerErrorHandler()

        _ = try? await client.request("/posts/1", method: .patch, parameters: ["text": "hi"])

        XCTAssertEqual(hits.count, 1)
    }

    func testFailedRetry_stillSurfacesServerError() async {
        _ = installServerErrorHandler()

        do {
            _ = try await client.request("/feed")
            XCTFail("expected a server error")
        } catch {
            guard case .serverError = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testDefaultRetryableMethods_areIdempotentOnly() {
        let methods = TransientNetworkRetrier().retryableMethods

        XCTAssertTrue(methods.contains(.get))
        XCTAssertTrue(methods.contains(.put))
        XCTAssertTrue(methods.contains(.delete))
        XCTAssertFalse(methods.contains(.post))
        XCTAssertFalse(methods.contains(.patch))
    }
}

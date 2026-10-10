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

    // MARK: - Status codes

    private func installHandler(status: Int, headers: [String: String] = [:]) -> Counter {
        let hits = Counter()
        MockURLProtocol.handler = { request in
            hits.increment()
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            return (response, nil)
        }
        return hits
    }

    func testGETOn501_isNotRetried() async {
        let hits = installHandler(status: 501)

        _ = try? await client.request("/feed")

        XCTAssertEqual(hits.count, 1)
    }

    func testGETOn500_502_504_areRetried() async {
        for status in [500, 502, 504] {
            let hits = installHandler(status: status)
            _ = try? await client.request("/feed")
            XCTAssertEqual(hits.count, 2, "\(status) should be retried once")
        }
    }

    // MARK: - Retry-After

    func testRetryAfterWithinCap_isHonoured() async {
        let hits = installHandler(status: 503, headers: ["Retry-After": "1"])

        let start = Date()
        _ = try? await client.request("/feed")

        XCTAssertEqual(hits.count, 2)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.9, "The retry must wait for Retry-After")
    }

    func testRetryAfterBeyondCap_isNotRetried() async {
        let hits = installHandler(status: 503, headers: ["Retry-After": "3600"])

        _ = try? await client.request("/feed")

        XCTAssertEqual(hits.count, 1)
    }

    func testRetryAfterParsing_delaySeconds() {
        XCTAssertEqual(TransientNetworkRetrier.retryAfterDelay("120"), 120)
        XCTAssertEqual(TransientNetworkRetrier.retryAfterDelay(" 0 "), 0)
        XCTAssertNil(TransientNetworkRetrier.retryAfterDelay("-5"))
        XCTAssertNil(TransientNetworkRetrier.retryAfterDelay("1.5"))
        XCTAssertNil(TransientNetworkRetrier.retryAfterDelay("soon"))
        XCTAssertNil(TransientNetworkRetrier.retryAfterDelay(""))
    }

    func testRetryAfterParsing_httpDate() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2015-10-21T07:28:00Z"))

        XCTAssertEqual(TransientNetworkRetrier.retryAfterDelay("Wed, 21 Oct 2015 07:28:30 GMT", now: now), 30)
        XCTAssertEqual(TransientNetworkRetrier.retryAfterDelay("Wed, 21 Oct 2015 07:27:00 GMT", now: now), 0, "A past date means retry now")
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

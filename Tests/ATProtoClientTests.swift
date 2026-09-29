import Alamofire
@testable import APWebAuthentication
import Foundation
import SwiftyJSON
import XCTest

@MainActor
final class ATProtoClientTests: XCTestCase {

    private final class MockATProtoClient: ATProtoClient {
        override func makeSessionConfiguration() -> URLSessionConfiguration {
            let configuration = super.makeSessionConfiguration()
            configuration.protocolClasses = [MockURLProtocol.self]
            return configuration
        }
    }

    private var auth: ATProtoAuthentication!
    private var client: MockATProtoClient!

    override func setUp() async throws {
        try await super.setUp()
        auth = ATProtoAuthentication()
        auth.did = "did:plc:abc"
        auth.pdsURL = URL(string: "https://pds.example.com")
        auth.accessToken = "access-1"
        auth.dpopKey = DPoPKey()
        client = MockATProtoClient(accountType: AccountStore.bluesky, auth: auth)
    }

    override func tearDown() async throws {
        MockURLProtocol.handler = nil
        try await super.tearDown()
    }

    // MARK: - Base URL

    func testBaseURL_targetsTheSessionsPDS() {
        XCTAssertEqual(client.baseURLString, "https://pds.example.com/xrpc/")

        auth.pdsURL = URL(string: "https://morel.us-east.host.bsky.network/")
        client.updateBaseURL()
        XCTAssertEqual(client.baseURLString, "https://morel.us-east.host.bsky.network/xrpc/")

        auth.pdsURL = nil
        client.updateBaseURL()
        XCTAssertEqual(client.baseURLString, "https://bsky.social/xrpc/")
    }

    // MARK: - Timestamps

    func testTimestamp_isRFC3339UTCWithMilliseconds() {
        XCTAssertEqual(ATProtoClient.timestamp(Date(timeIntervalSince1970: 1_700_000_000.5)), "2023-11-14T22:13:20.500Z")
        XCTAssertEqual(ATProtoClient.timestamp(Date(timeIntervalSince1970: 0)), "1970-01-01T00:00:00.000Z")

        let now = ATProtoClient.timestamp()
        XCTAssertNotNil(now.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$"#, options: .regularExpression), now)
    }

    // MARK: - Logging

    func testRequests_postAlamofireNotificationsForTheActivityLogger() async throws {
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 200, body: Data("{}".utf8))
        }
        let resumed = expectation(forNotification: Request.didResumeTaskNotification, object: nil)
        let completed = expectation(forNotification: Request.didCompleteTaskNotification, object: nil)

        _ = try await client.request("app.bsky.actor.getProfile", parameters: ["actor": "did:plc:abc"])

        await fulfillment(of: [resumed, completed], timeout: 2)
    }

    // MARK: - Rate Limits

    func testResetDate_acceptsUnixTimestampOrSecondsUntilReset() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(ATProtoClient.resetDate(from: 1_700_000_300, receivedAt: now), Date(timeIntervalSince1970: 1_700_000_300))
        XCTAssertEqual(ATProtoClient.resetDate(from: 45, receivedAt: now), now.addingTimeInterval(45))
    }

    func testRecordRateLimit_parsesHeadersAndIgnoresGarbage() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        client.recordRateLimit(remaining: "2988", reset: "1700000300", receivedAt: now)
        XCTAssertEqual(client.rateLimitRemaining, 2988)
        XCTAssertEqual(client.rateLimitResetDate, Date(timeIntervalSince1970: 1_700_000_300))

        client.recordRateLimit(remaining: "lots", reset: "soon", receivedAt: now)
        XCTAssertEqual(client.rateLimitRemaining, 2988, "unparseable headers leave the last good value")
        XCTAssertEqual(client.rateLimitResetDate, Date(timeIntervalSince1970: 1_700_000_300))
    }

    func testSuccessfulResponse_updatesRateLimitAndNonce() async throws {
        let reset = Int(Date().timeIntervalSince1970) + 120
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "DPoP access-1")
            XCTAssertNotNil(request.value(forHTTPHeaderField: "DPoP"))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: [
                "Content-Type": "application/json",
                "RateLimit-Limit": "3000",
                "RateLimit-Remaining": "2999",
                "RateLimit-Reset": "\(reset)",
                "DPoP-Nonce": "pds-nonce-1"
            ])!
            return (response, Data(#"{"did":"did:plc:abc","handle":"alice.bsky.social"}"#.utf8))
        }

        let json = try await client.request("app.bsky.actor.getProfile", parameters: ["actor": "did:plc:abc"])
        XCTAssertEqual(json["handle"].string, "alice.bsky.social")

        // The monitor reports on its own queue and hops to the main actor.
        try await waitUntil { self.client.rateLimitRemaining != nil && self.auth.resourceServerNonce != nil }
        XCTAssertEqual(client.rateLimitRemaining, 2999)
        XCTAssertEqual(client.rateLimitResetDate, Date(timeIntervalSince1970: TimeInterval(reset)))
        XCTAssertEqual(auth.resourceServerNonce, "pds-nonce-1")
    }

    func testTooManyRequests_isRateLimitWithMinutesUntilReset() async {
        let reset = Int(Date().timeIntervalSince1970) + 170 // rounds up to 3 minutes
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: [
                "Content-Type": "application/json",
                "RateLimit-Remaining": "0",
                "RateLimit-Reset": "\(reset)"
            ])!
            return (response, Data(#"{"error":"RateLimitExceeded","message":"Rate Limit Exceeded"}"#.utf8))
        }

        do {
            _ = try await client.request("app.bsky.graph.getFollowers", parameters: ["actor": "did:plc:abc"])
            XCTFail("Expected failure")
        } catch {
            guard case .rateLimit(let reason, let json) = error else { return XCTFail("Unexpected error \(error)") }
            XCTAssertEqual(reason, "Rate limit reached. Try again in 3 min.")
            XCTAssertEqual(json?["error"].string, "RateLimitExceeded")
        }
    }

    func testTooManyRequests_withoutResetHeaderStillIsRateLimit() async {
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 429, body: Data(#"{"error":"RateLimitExceeded"}"#.utf8))
        }

        do {
            _ = try await client.request("app.bsky.graph.getFollowers")
            XCTFail("Expected failure")
        } catch {
            guard case .rateLimit(let reason, _) = error else { return XCTFail("Unexpected error \(error)") }
            XCTAssertEqual(reason, "Rate limit reached.")
        }
    }

    // MARK: - Errors

    func testXRPCError_usesMessageThenErrorCode() async {
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 400, body: Data(#"{"error":"InvalidRequest","message":"Profile not found"}"#.utf8))
        }
        do {
            _ = try await client.request("app.bsky.actor.getProfile")
            XCTFail("Expected failure")
        } catch {
            guard case .failed(let reason, _) = error else { return XCTFail("Unexpected error \(error)") }
            XCTAssertEqual(reason, "Profile not found")
        }

        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 400, body: Data(#"{"error":"InvalidRequest"}"#.utf8))
        }
        do {
            _ = try await client.request("app.bsky.actor.getProfile")
            XCTFail("Expected failure")
        } catch {
            guard case .failed(let reason, _) = error else { return XCTFail("Unexpected error \(error)") }
            XCTAssertEqual(reason, "InvalidRequest")
        }
    }

    // MARK: - Helpers

    private func waitUntil(timeout: TimeInterval = 2, _ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Condition not met within \(timeout)s")
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

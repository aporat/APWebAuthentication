@testable import APWebAuthentication
import SwiftyJSON
import XCTest

@MainActor
final class AuthClientEmptyResponseTests: XCTestCase {

    var client: MockTransportClient!

    override func setUp() async throws {
        try await super.setUp()
        client = MockTransportClient()
    }

    override func tearDown() async throws {
        MockURLProtocol.handler = nil
        try await super.tearDown()
    }

    func testNoContentResponse_succeedsWithNullJSON() async throws {
        MockURLProtocol.handler = { MockURLProtocol.response(for: $0, status: 204) }

        let json = try await client.request("/user/starred/owner/repo", method: .put)

        XCTAssertEqual(json, JSON.null)
    }

    func testResetContentResponse_succeedsWithNullJSON() async throws {
        MockURLProtocol.handler = { MockURLProtocol.response(for: $0, status: 205) }

        let json = try await client.request("/thing", method: .delete)

        XCTAssertEqual(json, JSON.null)
    }

    func testNoContentResponse_requestWithResponse_exposesStatusCode() async throws {
        MockURLProtocol.handler = { MockURLProtocol.response(for: $0, status: 204) }

        let (json, response) = try await client.requestWithResponse("/thing", method: .delete)

        XCTAssertEqual(json, JSON.null)
        XCTAssertEqual(response.statusCode, 204)
    }

    func testEmptyBodyOn200_stillFails() async throws {
        // A 200 with no body is not a declared empty-response code and should
        // still be surfaced as an error rather than silently succeeding.
        MockURLProtocol.handler = { MockURLProtocol.response(for: $0, status: 200) }

        do {
            _ = try await client.request("/thing")
            XCTFail("expected a serialization failure")
        } catch {
            guard case .failed = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testJSONBody_stillParses() async throws {
        MockURLProtocol.handler = {
            MockURLProtocol.response(for: $0, status: 200, body: Data(#"{"login":"octocat"}"#.utf8))
        }

        let json = try await client.request("/user")

        XCTAssertEqual(json["login"].string, "octocat")
    }
}

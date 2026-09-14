import Alamofire
@testable import APWebAuthentication
import XCTest

/// Runs an OAuth2 client end-to-end through the mock transport so the
/// transient retrier and the token-refresh retrier interact exactly as
/// Alamofire composes them.
@MainActor
final class OAuth2RetryAfterTransientTests: XCTestCase {

    private nonisolated static let tokenPath = "/oauth2/token"

    /// Records every hit per path and the Authorization header on each.
    private final class Journal: @unchecked Sendable {
        private let lock = NSLock()
        private var _hits: [String: [String?]] = [:]

        func record(_ request: URLRequest) -> Int {
            lock.withLock {
                let path = request.url!.path
                _hits[path, default: []].append(request.value(forHTTPHeaderField: "Authorization"))
                return _hits[path]!.count
            }
        }

        func hits(_ path: String) -> [String?] {
            lock.withLock { _hits[path] ?? [] }
        }
    }

    /// OAuth2 client whose API session and refresh session both use the mock transport.
    private final class MockOAuth2Client: OAuth2Client {
        init(auth: Auth2Authentication) {
            let refreshConfiguration = URLSessionConfiguration.ephemeral
            refreshConfiguration.protocolClasses = [MockURLProtocol.self]
            let interceptor = OAuth2Interceptor(
                auth: auth,
                tokenLocation: .authorizationHeader,
                refreshTokenURL: "https://api.example.com" + OAuth2RetryAfterTransientTests.tokenPath,
                refreshSession: Session(configuration: refreshConfiguration)
            )
            super.init(
                accountType: AccountStore.x,
                baseURLString: "https://api.example.com/",
                requestInterceptor: interceptor
            )
        }

        override func makeSessionConfiguration() -> URLSessionConfiguration {
            let configuration = super.makeSessionConfiguration()
            configuration.protocolClasses = [MockURLProtocol.self]
            return configuration
        }
    }

    private var auth: Auth2Authentication!
    private var client: MockOAuth2Client!

    override func setUp() async throws {
        try await super.setUp()
        auth = Auth2Authentication()
        auth.clientId = "client"
        auth.clientSecret = "secret"
        auth.accessToken = "old-token"
        auth.refreshToken = "old-refresh"
        client = MockOAuth2Client(auth: auth)
    }

    override func tearDown() async throws {
        MockURLProtocol.handler = nil
        try await super.tearDown()
    }

    private nonisolated static let tokenResponse = Data(#"{"access_token":"new-token","refresh_token":"new-refresh"}"#.utf8)

    // MARK: - Tests

    func test401AfterTransientRetry_stillRefreshesAndSucceeds() async throws {
        let journal = Journal()
        MockURLProtocol.handler = { request in
            let hit = journal.record(request)
            switch (request.url!.path, hit) {
            case (Self.tokenPath, _):
                return MockURLProtocol.response(for: request, status: 200, body: Self.tokenResponse)
            case ("/feed", 1):
                return MockURLProtocol.response(for: request, status: 503)   // transient → retried
            case ("/feed", 2):
                return MockURLProtocol.response(for: request, status: 401)   // expired → refresh
            default:
                return MockURLProtocol.response(for: request, status: 200, body: Data(#"{"ok":true}"#.utf8))
            }
        }

        let json = try await client.request("/feed")

        XCTAssertEqual(json["ok"].bool, true)
        XCTAssertEqual(journal.hits(Self.tokenPath).count, 1)
        XCTAssertEqual(journal.hits("/feed"), ["Bearer old-token", "Bearer old-token", "Bearer new-token"])
        XCTAssertEqual(auth.accessToken, "new-token")
    }

    func test401Directly_refreshesAndSucceeds() async throws {
        let journal = Journal()
        MockURLProtocol.handler = { request in
            let hit = journal.record(request)
            switch (request.url!.path, hit) {
            case (Self.tokenPath, _):
                return MockURLProtocol.response(for: request, status: 200, body: Self.tokenResponse)
            case ("/me", 1):
                return MockURLProtocol.response(for: request, status: 401)
            default:
                return MockURLProtocol.response(for: request, status: 200, body: Data(#"{"ok":true}"#.utf8))
            }
        }

        let json = try await client.request("/me")

        XCTAssertEqual(json["ok"].bool, true)
        XCTAssertEqual(journal.hits(Self.tokenPath).count, 1)
        XCTAssertEqual(journal.hits("/me"), ["Bearer old-token", "Bearer new-token"])
    }

    func test401AfterRefresh_isNotRefreshedAgain() async {
        let journal = Journal()
        MockURLProtocol.handler = { request in
            _ = journal.record(request)
            if request.url!.path == Self.tokenPath {
                return MockURLProtocol.response(for: request, status: 200, body: Self.tokenResponse)
            }
            return MockURLProtocol.response(for: request, status: 401)   // still rejected after refresh
        }

        do {
            _ = try await client.request("/me")
            XCTFail("expected sessionExpired")
        } catch {
            guard case .sessionExpired = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }

        XCTAssertEqual(journal.hits(Self.tokenPath).count, 1)
        XCTAssertEqual(journal.hits("/me"), ["Bearer old-token", "Bearer new-token"])
    }

    func testConcurrent401s_shareOneRefresh() async throws {
        let journal = Journal()
        MockURLProtocol.handler = { request in
            let hit = journal.record(request)
            if request.url!.path == Self.tokenPath {
                return MockURLProtocol.response(for: request, status: 200, body: Self.tokenResponse)
            }
            return hit == 1
                ? MockURLProtocol.response(for: request, status: 401)
                : MockURLProtocol.response(for: request, status: 200, body: Data(#"{"ok":true}"#.utf8))
        }

        // JSON is not Sendable, so reduce each result to a Bool inside a
        // main-actor task before it crosses the task boundary.
        let client = self.client!
        let tasks = ["/a", "/b", "/c"].map { path in
            Task { @MainActor in try await client.request(path)["ok"].boolValue }
        }
        var results: [Bool] = []
        for task in tasks {
            results.append(try await task.value)
        }

        XCTAssertEqual(results, [true, true, true])
        XCTAssertEqual(journal.hits(Self.tokenPath).count, 1)
    }
}

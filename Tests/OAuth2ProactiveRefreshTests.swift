import Alamofire
@testable import APWebAuthentication
import SwiftyJSON
import XCTest

/// Proactive (pre-expiry) OAuth 2.0 refresh, driven end-to-end through the
/// mock transport with an injected clock.
@MainActor
final class OAuth2ProactiveRefreshTests: XCTestCase {

    private nonisolated static let tokenPath = "/oauth2/token"
    private nonisolated static let tokenResponse = Data(#"{"access_token":"new-token","refresh_token":"new-refresh","expires_in":3600}"#.utf8)

    /// Records every hit per path and the Authorization header on each.
    private final class Journal: @unchecked Sendable {
        private let lock = NSLock()
        private var _hits: [String: [String?]] = [:]

        func record(_ request: URLRequest) {
            lock.withLock {
                _hits[request.url!.path, default: []].append(request.value(forHTTPHeaderField: "Authorization"))
            }
        }

        func hits(_ path: String) -> [String?] {
            lock.withLock { _hits[path] ?? [] }
        }
    }

    /// A settable clock.
    private final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var _now: Date
        init(_ now: Date) { _now = now }
        var now: Date {
            get { lock.withLock { _now } }
            set { lock.withLock { _now = newValue } }
        }
    }

    private final class MockOAuth2Client: OAuth2Client {
        init(auth: Auth2Authentication, clock: Clock, refreshTokenURL: String? = "https://api.example.com" + OAuth2ProactiveRefreshTests.tokenPath) {
            let refreshConfiguration = URLSessionConfiguration.ephemeral
            refreshConfiguration.protocolClasses = [MockURLProtocol.self]
            let interceptor = OAuth2Interceptor(
                auth: auth,
                refreshTokenURL: refreshTokenURL,
                refreshSession: Session(configuration: refreshConfiguration),
                now: { clock.now }
            )
            super.init(accountType: AccountStore.x, baseURLString: "https://api.example.com/", requestInterceptor: interceptor)
        }

        override func makeSessionConfiguration() -> URLSessionConfiguration {
            let configuration = super.makeSessionConfiguration()
            configuration.protocolClasses = [MockURLProtocol.self]
            return configuration
        }
    }

    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private var clock: Clock!
    private var auth: Auth2Authentication!
    private var client: MockOAuth2Client!

    override func setUp() async throws {
        try await super.setUp()
        clock = Clock(start)
        auth = Auth2Authentication()
        auth.clientId = "client"
        auth.accessToken = "old-token"
        auth.refreshToken = "old-refresh"
        client = MockOAuth2Client(auth: auth, clock: clock)
    }

    override func tearDown() async throws {
        MockURLProtocol.handler = nil
        try await super.tearDown()
    }

    /// Token endpoint answers `tokenStatus`; everything else answers 200.
    private func installServer(tokenStatus: Int = 200) -> Journal {
        let journal = Journal()
        MockURLProtocol.handler = { request in
            journal.record(request)
            if request.url!.path == Self.tokenPath {
                return MockURLProtocol.response(
                    for: request,
                    status: tokenStatus,
                    body: tokenStatus == 200 ? Self.tokenResponse : Data(#"{"error":"temporarily_unavailable"}"#.utf8)
                )
            }
            return MockURLProtocol.response(for: request, status: 200, body: Data(#"{"ok":true}"#.utf8))
        }
        return journal
    }

    // MARK: - Proactive refresh

    func testNearExpiry_refreshesBeforeSending() async throws {
        auth.expiresAt = start.addingTimeInterval(30)   // inside the 60 s leeway
        let journal = installServer()

        _ = try await client.request("/me")

        XCTAssertEqual(journal.hits(Self.tokenPath).count, 1)
        XCTAssertEqual(journal.hits("/me"), ["Bearer new-token"], "The request goes out with the refreshed token")
        XCTAssertEqual(auth.accessToken, "new-token")
        XCTAssertEqual(auth.refreshToken, "new-refresh", "A rotated refresh token is stored")
        XCTAssertEqual(auth.expiresAt, start.addingTimeInterval(3600))
    }

    func testAlreadyExpired_refreshesBeforeSending() async throws {
        auth.expiresAt = start.addingTimeInterval(-600)
        let journal = installServer()

        _ = try await client.request("/me")

        XCTAssertEqual(journal.hits(Self.tokenPath).count, 1)
        XCTAssertEqual(journal.hits("/me"), ["Bearer new-token"])
    }

    func testFreshToken_doesNotRefresh() async throws {
        auth.expiresAt = start.addingTimeInterval(3600)
        let journal = installServer()

        _ = try await client.request("/me")

        XCTAssertTrue(journal.hits(Self.tokenPath).isEmpty)
        XCTAssertEqual(journal.hits("/me"), ["Bearer old-token"])
    }

    func testUnknownExpiry_doesNotRefresh() async throws {
        auth.expiresAt = nil
        let journal = installServer()

        _ = try await client.request("/me")

        XCTAssertTrue(journal.hits(Self.tokenPath).isEmpty)
        XCTAssertEqual(journal.hits("/me"), ["Bearer old-token"])
    }

    func testRefreshNotConfigured_doesNotRefresh() async throws {
        client = MockOAuth2Client(auth: auth, clock: clock, refreshTokenURL: nil)
        auth.expiresAt = start.addingTimeInterval(-600)
        let journal = installServer()

        _ = try await client.request("/me")

        XCTAssertTrue(journal.hits(Self.tokenPath).isEmpty)
        XCTAssertEqual(journal.hits("/me"), ["Bearer old-token"])
    }

    func testClockAdvancingIntoLeeway_triggersRefresh() async throws {
        auth.expiresAt = start.addingTimeInterval(3600)
        let journal = installServer()

        _ = try await client.request("/me")
        XCTAssertTrue(journal.hits(Self.tokenPath).isEmpty)

        clock.now = start.addingTimeInterval(3600 - 59)
        _ = try await client.request("/me")

        XCTAssertEqual(journal.hits(Self.tokenPath).count, 1)
        XCTAssertEqual(journal.hits("/me"), ["Bearer old-token", "Bearer new-token"])
    }

    func testConcurrentRequests_shareOneRefresh() async throws {
        auth.expiresAt = start.addingTimeInterval(10)
        let journal = installServer()
        let client = self.client!

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<5 {
                group.addTask { @MainActor in
                    _ = try await client.request("/item/\(index)")
                }
            }
            try await group.waitForAll()
        }

        XCTAssertEqual(journal.hits(Self.tokenPath).count, 1, "Concurrent requests must share one refresh")
        for index in 0..<5 {
            XCTAssertEqual(journal.hits("/item/\(index)"), ["Bearer new-token"])
        }
    }

    func testRefreshFailure_fallsBackToCurrentTokenAndBacksOff() async throws {
        auth.expiresAt = start.addingTimeInterval(30)
        let journal = installServer(tokenStatus: 503)

        _ = try await client.request("/me")

        XCTAssertEqual(journal.hits(Self.tokenPath).count, 1)
        XCTAssertEqual(journal.hits("/me"), ["Bearer old-token"], "A failed refresh still sends the current token")
        XCTAssertEqual(auth.accessToken, "old-token")
        XCTAssertEqual(auth.refreshToken, "old-refresh")

        // Within the backoff window no new proactive attempt is made.
        clock.now = start.addingTimeInterval(10)
        _ = try await client.request("/me")
        XCTAssertEqual(journal.hits(Self.tokenPath).count, 1)

        // After it, the next request tries again.
        clock.now = start.addingTimeInterval(31)
        _ = try await client.request("/me")
        XCTAssertEqual(journal.hits(Self.tokenPath).count, 2)
    }

    func testForeignHost_doesNotTriggerRefresh() async throws {
        auth.expiresAt = start.addingTimeInterval(-600)
        let journal = installServer()

        _ = try await client.request("https://cdn.example.net/file")

        XCTAssertTrue(journal.hits(Self.tokenPath).isEmpty)
        XCTAssertEqual(journal.hits("/file"), [nil])
    }

    func testRefreshWithoutExpiresIn_clearsExpiry() async {
        auth.expiresAt = start.addingTimeInterval(30)
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 200, body: Data(#"{"access_token":"new-token"}"#.utf8))
        }

        let refreshed = await client.interceptor.refreshAccessToken(url: "https://api.example.com" + Self.tokenPath)

        XCTAssertTrue(refreshed)
        XCTAssertNil(auth.expiresAt, "An expiry that described the old token must not linger")
        XCTAssertEqual(auth.refreshToken, "old-refresh", "No rotation → keep the old refresh token")
    }

    func testRefreshWithStringExpiresIn_isAccepted() async {
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 200, body: Data(#"{"access_token":"new-token","expires_in":"7200"}"#.utf8))
        }

        let refreshed = await client.interceptor.refreshAccessToken(url: "https://api.example.com" + Self.tokenPath)

        XCTAssertTrue(refreshed)
        XCTAssertEqual(auth.expiresAt, start.addingTimeInterval(7200))
    }

    // MARK: - Auth2Authentication

    func testIsAccessTokenExpiring() {
        auth.expiresAt = nil
        XCTAssertFalse(auth.isAccessTokenExpiring(within: 60, now: start))

        auth.expiresAt = start.addingTimeInterval(61)
        XCTAssertFalse(auth.isAccessTokenExpiring(within: 60, now: start))
        XCTAssertTrue(auth.isAccessTokenExpiring(within: 60, now: start.addingTimeInterval(1)))

        auth.expiresAt = start.addingTimeInterval(-1)
        XCTAssertTrue(auth.isAccessTokenExpiring(within: 0, now: start))
    }

    func testApplyTokenResponse_setsTokensAndExpiry() {
        let fresh = Auth2Authentication()
        fresh.refreshToken = "keep-me"

        XCTAssertTrue(fresh.applyTokenResponse(JSON(["access_token": "a", "expires_in": 120]), now: start))
        XCTAssertEqual(fresh.accessToken, "a")
        XCTAssertEqual(fresh.refreshToken, "keep-me")
        XCTAssertEqual(fresh.expiresAt, start.addingTimeInterval(120))

        // Implicit-flow callback parameters are all strings.
        XCTAssertTrue(fresh.applyTokenResponse(JSON(["access_token": "b", "refresh_token": "r2", "expires_in": "300"]), now: start))
        XCTAssertEqual(fresh.accessToken, "b")
        XCTAssertEqual(fresh.refreshToken, "r2")
        XCTAssertEqual(fresh.expiresAt, start.addingTimeInterval(300))

        XCTAssertTrue(fresh.applyTokenResponse(JSON(["access_token": "c"]), now: start))
        XCTAssertNil(fresh.expiresAt)

        XCTAssertFalse(fresh.applyTokenResponse(JSON(["error": "access_denied"]), now: start))
        XCTAssertEqual(fresh.accessToken, "c")
    }

    // MARK: - Persistence

    func testSettings_roundTripExpiresAt() throws {
        auth.expiresAt = start.addingTimeInterval(3600)

        let data = try PropertyListEncoder().encode(auth.persistedSettings)
        let decoded = try PropertyListDecoder().decode(Auth2Authentication.AuthSettings.self, from: data)

        let restored = Auth2Authentication()
        restored.restore(from: decoded)
        XCTAssertEqual(restored.accessToken, "old-token")
        XCTAssertEqual(restored.refreshToken, "old-refresh")
        XCTAssertEqual(restored.clientId, "client")
        XCTAssertEqual(restored.expiresAt, start.addingTimeInterval(3600))
    }

    /// The shape `Auth2Authentication` persisted before `expiresAt` existed.
    private struct LegacySettings: Codable {
        let accessToken: String?
        let refreshToken: String?
        let clientId: String?
        let clientSecret: String?
    }

    func testSettings_decodeLegacyBlobWithoutExpiresAt() throws {
        let legacy = LegacySettings(accessToken: "legacy-token", refreshToken: "legacy-refresh", clientId: "cid", clientSecret: nil)
        let data = try PropertyListEncoder().encode(legacy)

        let decoded = try PropertyListDecoder().decode(Auth2Authentication.AuthSettings.self, from: data)

        let restored = Auth2Authentication()
        restored.expiresAt = Date()
        restored.restore(from: decoded)
        XCTAssertEqual(restored.accessToken, "legacy-token")
        XCTAssertEqual(restored.refreshToken, "legacy-refresh")
        XCTAssertEqual(restored.clientId, "cid")
        XCTAssertNil(restored.expiresAt)
    }

    func testDelete_clearsExpiresAt() async {
        auth.expiresAt = start
        await auth.delete()
        XCTAssertNil(auth.expiresAt)
    }
}

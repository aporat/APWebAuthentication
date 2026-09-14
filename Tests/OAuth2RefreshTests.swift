import Alamofire
@testable import APWebAuthentication
import XCTest

/// Runs the refresh-token grant through the mock transport and inspects
/// exactly what reaches the token endpoint.
@MainActor
final class OAuth2RefreshTests: XCTestCase {

    private static let tokenURL = "https://auth.example.com/oauth2/token"

    /// Captures the last request the token endpoint received.
    private final class Capture: @unchecked Sendable {
        private let lock = NSLock()
        private var _request: URLRequest?
        var request: URLRequest? {
            get { lock.withLock { _request } }
            set { lock.withLock { _request = newValue } }
        }
    }

    private var auth: Auth2Authentication!

    override func setUp() async throws {
        try await super.setUp()
        auth = Auth2Authentication()
        auth.clientId = "client-123"
        auth.accessToken = "old-access"
        auth.refreshToken = "old-refresh"
    }

    override func tearDown() async throws {
        MockURLProtocol.handler = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeInterceptor(_ mode: OAuth2ClientAuthentication) -> OAuth2Interceptor {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return OAuth2Interceptor(
            auth: auth,
            tokenLocation: .authorizationHeader,
            refreshTokenURL: Self.tokenURL,
            clientAuthentication: mode,
            refreshSession: Session(configuration: configuration)
        )
    }

    private func installTokenEndpoint(status: Int = 200, body: String = #"{"access_token":"new-access","refresh_token":"new-refresh","token_type":"bearer"}"#) -> Capture {
        let capture = Capture()
        MockURLProtocol.handler = { request in
            capture.request = request
            return MockURLProtocol.response(for: request, status: status, body: Data(body.utf8))
        }
        return capture
    }

    /// Reads the form body of a captured request. URLProtocol only exposes
    /// the body as a stream, so drain it.
    private func formBody(of request: URLRequest?) -> [String: String] {
        guard let request else { return [:] }
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                guard read > 0 else { break }
                data.append(buffer, count: read)
            }
        }
        let pairs = URL.parseFormURLEncoded(String(decoding: data, as: UTF8.self))
        return pairs.reduce(into: [:]) { $0[$1.0] = $1.1 }
    }

    // MARK: - X style: Basic header for confidential clients

    func testBasicMode_confidentialClient_usesBasicHeaderAndOmitsSecretFromBody() async {
        auth.clientSecret = "s3cret"
        let capture = installTokenEndpoint()

        let refreshed = await makeInterceptor(.basicAuthorizationHeader).refreshAccessToken(url: Self.tokenURL)

        XCTAssertTrue(refreshed)
        let expectedBasic = "Basic " + Data("client-123:s3cret".utf8).base64EncodedString()
        XCTAssertEqual(capture.request?.value(forHTTPHeaderField: "Authorization"), expectedBasic)

        let body = formBody(of: capture.request)
        XCTAssertEqual(body["grant_type"], "refresh_token")
        XCTAssertEqual(body["refresh_token"], "old-refresh")
        XCTAssertEqual(body["client_id"], "client-123")
        XCTAssertNil(body["client_secret"])
    }

    func testBasicMode_publicClient_sendsClientIdOnly() async {
        auth.clientSecret = nil
        let capture = installTokenEndpoint()

        let refreshed = await makeInterceptor(.basicAuthorizationHeader).refreshAccessToken(url: Self.tokenURL)

        XCTAssertTrue(refreshed)
        XCTAssertNil(capture.request?.value(forHTTPHeaderField: "Authorization"))
        let body = formBody(of: capture.request)
        XCTAssertEqual(body["client_id"], "client-123")
        XCTAssertNil(body["client_secret"])
    }

    // MARK: - Tumblr style: secret in the body

    func testBodyMode_confidentialClient_sendsSecretInBody() async {
        auth.clientSecret = "s3cret"
        let capture = installTokenEndpoint()

        let refreshed = await makeInterceptor(.requestBody).refreshAccessToken(url: Self.tokenURL)

        XCTAssertTrue(refreshed)
        XCTAssertNil(capture.request?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(formBody(of: capture.request)["client_secret"], "s3cret")
    }

    // MARK: - Credential updates

    func testSuccessfulRefresh_updatesTokens() async {
        auth.clientSecret = "s3cret"
        _ = installTokenEndpoint()

        _ = await makeInterceptor(.basicAuthorizationHeader).refreshAccessToken(url: Self.tokenURL)

        XCTAssertEqual(auth.accessToken, "new-access")
        XCTAssertEqual(auth.refreshToken, "new-refresh")
    }

    func testRejectedRefresh_clearsTokens() async {
        auth.clientSecret = "s3cret"
        _ = installTokenEndpoint(status: 400, body: #"{"error":"invalid_grant"}"#)

        let refreshed = await makeInterceptor(.basicAuthorizationHeader).refreshAccessToken(url: Self.tokenURL)

        XCTAssertFalse(refreshed)
        XCTAssertNil(auth.accessToken)
        XCTAssertNil(auth.refreshToken)
    }

    func testTransientFailure_keepsTokens() async {
        auth.clientSecret = "s3cret"
        _ = installTokenEndpoint(status: 503, body: "")

        let refreshed = await makeInterceptor(.basicAuthorizationHeader).refreshAccessToken(url: Self.tokenURL)

        XCTAssertFalse(refreshed)
        XCTAssertEqual(auth.accessToken, "old-access")
        XCTAssertEqual(auth.refreshToken, "old-refresh")
    }

    func testMissingRefreshToken_doesNotCallEndpoint() async {
        auth.refreshToken = nil
        let capture = installTokenEndpoint()

        let refreshed = await makeInterceptor(.basicAuthorizationHeader).refreshAccessToken(url: Self.tokenURL)

        XCTAssertFalse(refreshed)
        XCTAssertNil(capture.request)
    }

    func testXClient_isConfiguredForBasicClientAuthentication() {
        let client = XAPIClient(auth: auth)

        XCTAssertEqual(client.interceptor.refreshTokenURL, "https://api.x.com/2/oauth2/token")
        guard case .basicAuthorizationHeader = client.interceptor.clientAuthentication else {
            return XCTFail("X must use Basic client authentication at the token endpoint")
        }
    }
}

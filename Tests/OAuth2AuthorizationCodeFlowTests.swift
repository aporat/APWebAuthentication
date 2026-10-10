import Alamofire
@testable import APWebAuthentication
import Foundation
import SwiftyJSON
import XCTest

@MainActor
final class OAuth2AuthorizationCodeFlowTests: XCTestCase {

    private static let tokenURL = URL(string: "https://auth.example.com/oauth/token")!
    private static let redirect = URL(string: "myapp://oauth/callback")!
    private static let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    private static let challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

    override func tearDown() async throws {
        MockURLProtocol.handler = nil
    }

    // MARK: - Fixtures

    private func configuration(
        clientSecret: String? = nil,
        clientAuthentication: OAuth2ClientAuthentication = .requestBody,
        scopes: [String] = ["read", "write+all"],
        extra: [String: String] = [:],
        usesPKCE: Bool = true
    ) -> OAuth2AuthorizationCodeConfiguration {
        OAuth2AuthorizationCodeConfiguration(
            authorizeURL: URL(string: "https://auth.example.com/oauth/authorize?tenant=a%20b")!,
            tokenURL: Self.tokenURL,
            clientId: "client-1",
            redirectURI: Self.redirect,
            clientSecret: clientSecret,
            clientAuthentication: clientAuthentication,
            scopes: scopes,
            additionalAuthorizationParameters: extra,
            usesPKCE: usesPKCE
        )
    }

    private func makeFlow(_ configuration: OAuth2AuthorizationCodeConfiguration) -> OAuth2AuthorizationCodeFlow {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        return OAuth2AuthorizationCodeFlow(configuration: configuration, session: Session(configuration: sessionConfiguration))
    }

    private func pendingRequest(_ flow: OAuth2AuthorizationCodeFlow) throws -> OAuth2AuthorizationRequest {
        flow.makeAuthorizationRequest(state: "state-123", pkce: try PKCE(verifier: Self.verifier))
    }

    private func queryItems(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return items.reduce(into: [:]) { $0[$1.name] = $1.value }
    }

    /// Captures the token request and answers with `status`/`body`.
    private func installTokenEndpoint(
        status: Int = 200,
        body: [String: Any] = ["access_token": "at-1", "refresh_token": "rt-1", "token_type": "bearer", "expires_in": 7200, "scope": "read"]
    ) -> LockedResult<URLRequest?> {
        let captured = LockedResult<URLRequest?>(initial: nil)
        let data = try? JSONSerialization.data(withJSONObject: body)
        MockURLProtocol.handler = { request in
            captured.value = request
            return MockURLProtocol.response(for: request, status: status, body: data)
        }
        return captured
    }

    nonisolated private static func formBody(of request: URLRequest) -> [String: String] {
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
        return URL.parseFormURLEncoded(String(bytes: data, encoding: .utf8) ?? "")
            .reduce(into: [:]) { $0[$1.0] = $1.1 }
    }

    private func basic(_ user: String, _ password: String) -> String {
        "Basic " + Data("\(user):\(password)".utf8).base64EncodedString()
    }

    private func expectFailure(
        _ operation: () async throws(APWebAuthenticationError) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> APWebAuthenticationError? {
        do {
            try await operation()
            XCTFail("Expected an error", file: file, line: line)
            return nil
        } catch {
            return error
        }
    }

    // MARK: - Authorization URL

    func testAuthorizationURL_containsCodeStateAndS256Challenge() throws {
        let flow = makeFlow(configuration())
        let request = try pendingRequest(flow)
        let items = queryItems(request.url)

        XCTAssertEqual(request.url.host, "auth.example.com")
        XCTAssertEqual(request.url.path, "/oauth/authorize")
        XCTAssertEqual(items["tenant"], "a b", "existing query is kept")
        XCTAssertEqual(items["response_type"], "code")
        XCTAssertEqual(items["client_id"], "client-1")
        XCTAssertEqual(items["redirect_uri"], "myapp://oauth/callback")
        XCTAssertEqual(items["scope"], "read write+all")
        XCTAssertEqual(items["state"], "state-123")
        XCTAssertEqual(items["code_challenge"], Self.challenge)
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(request.state, "state-123")
        XCTAssertEqual(request.pkce?.verifier, Self.verifier)
        XCTAssertEqual(request.redirectURI, Self.redirect)

        // Spaces and `+` are percent-encoded so no server reads `+` as a space.
        let query = try XCTUnwrap(request.url.query(percentEncoded: true))
        XCTAssertTrue(query.contains("scope=read%20write%2Ball"), query)
        XCTAssertTrue(query.contains("redirect_uri=myapp%3A%2F%2Foauth%2Fcallback"), query)
    }

    func testAuthorizationURL_extraParametersCannotOverrideFlowParameters() throws {
        let flow = makeFlow(configuration(extra: [
            "prompt": "consent",
            "state": "attacker",
            "code_challenge_method": "plain",
            "response_type": "token"
        ]))
        let items = queryItems(try pendingRequest(flow).url)

        XCTAssertEqual(items["prompt"], "consent")
        XCTAssertEqual(items["state"], "state-123")
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(items["response_type"], "code")
    }

    func testAuthorizationURL_scopeSeparatorAndEmptyScopes() {
        var config = configuration(scopes: ["a", "b"])
        config.scopeSeparator = ","
        XCTAssertEqual(queryItems(makeFlow(config).makeAuthorizationRequest().url)["scope"], "a,b")

        XCTAssertNil(queryItems(makeFlow(configuration(scopes: [])).makeAuthorizationRequest().url)["scope"])
    }

    func testAuthorizationURL_withoutPKCE() {
        let request = makeFlow(configuration(usesPKCE: false)).makeAuthorizationRequest()
        let items = queryItems(request.url)

        XCTAssertNil(request.pkce)
        XCTAssertNil(items["code_challenge"])
        XCTAssertNil(items["code_challenge_method"])
    }

    func testAuthorizationURL_generatesFreshStateAndVerifier() throws {
        let flow = makeFlow(configuration())
        let first = flow.makeAuthorizationRequest()
        let second = flow.makeAuthorizationRequest()

        XCTAssertGreaterThanOrEqual(first.state.count, 43)
        XCTAssertNotEqual(first.state, second.state)
        let firstPKCE = try XCTUnwrap(first.pkce)
        XCTAssertNotEqual(firstPKCE.verifier, second.pkce?.verifier)
        XCTAssertEqual(queryItems(first.url)["code_challenge"], firstPKCE.challenge)
    }

    // MARK: - Callback Validation

    func testCallback_returnsCode() throws {
        let flow = makeFlow(configuration())
        let request = try pendingRequest(flow)

        let code = try flow.authorizationCode(
            from: URL(string: "myapp://oauth/callback?code=abc%2B1&state=state-123")!,
            for: request
        )
        XCTAssertEqual(code, "abc+1")
    }

    func testCallback_stateMismatchOrMissing_isRejected() throws {
        let flow = makeFlow(configuration())
        let request = try pendingRequest(flow)

        for url in ["myapp://oauth/callback?code=abc&state=other", "myapp://oauth/callback?code=abc"] {
            XCTAssertThrowsError(try flow.authorizationCode(from: URL(string: url)!, for: request)) { error in
                XCTAssertEqual(error as? APWebAuthenticationError, .failed(reason: "OAuth state mismatch — possible CSRF."), url)
            }
        }
    }

    func testCallback_stateIsCheckedBeforeError() throws {
        let flow = makeFlow(configuration())
        let request = try pendingRequest(flow)

        // A forged `access_denied` without our state must not read as a user cancel.
        XCTAssertThrowsError(try flow.authorizationCode(
            from: URL(string: "myapp://oauth/callback?error=access_denied&state=forged")!,
            for: request
        )) { error in
            XCTAssertEqual(error as? APWebAuthenticationError, .failed(reason: "OAuth state mismatch — possible CSRF."))
        }
    }

    func testCallback_errors() throws {
        let flow = makeFlow(configuration())
        let request = try pendingRequest(flow)

        XCTAssertThrowsError(try flow.authorizationCode(
            from: URL(string: "myapp://oauth/callback?error=access_denied&state=state-123")!,
            for: request
        )) { error in
            XCTAssertEqual(error as? APWebAuthenticationError, .canceled)
        }

        XCTAssertThrowsError(try flow.authorizationCode(
            from: URL(string: "myapp://oauth/callback?error=invalid_scope&error_description=Bad+scope&state=state-123")!,
            for: request
        )) { error in
            XCTAssertEqual(error as? APWebAuthenticationError, .failed(reason: "Bad scope"))
        }

        XCTAssertThrowsError(try flow.authorizationCode(
            from: URL(string: "myapp://oauth/callback?state=state-123")!,
            for: request
        )) { error in
            XCTAssertEqual(error as? APWebAuthenticationError, .failed(reason: "No authorization code received."))
        }
    }

    func testCallback_foreignRedirectIsRejected() throws {
        let flow = makeFlow(configuration())
        let request = try pendingRequest(flow)

        for url in ["myapp://evil/callback?code=abc&state=state-123", "other://oauth/callback?code=abc&state=state-123"] {
            XCTAssertThrowsError(try flow.authorizationCode(from: URL(string: url)!, for: request)) { error in
                XCTAssertEqual(error as? APWebAuthenticationError, .failed(reason: "The login returned to an unexpected address."), url)
            }
        }
    }

    // MARK: - Code Exchange

    func testExchange_publicClient_sendsVerifierAndNoSecret() async throws {
        let flow = makeFlow(configuration(clientAuthentication: .basicAuthorizationHeader))
        let request = try pendingRequest(flow)
        let captured = installTokenEndpoint()

        let token = try await flow.exchangeCode("code-1", for: request)

        let sent = try XCTUnwrap(captured.value)
        XCTAssertEqual(sent.httpMethod, "POST")
        XCTAssertEqual(sent.url, Self.tokenURL)
        XCTAssertNil(sent.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertTrue(sent.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("application/x-www-form-urlencoded") == true)
        XCTAssertEqual(Self.formBody(of: sent), [
            "grant_type": "authorization_code",
            "code": "code-1",
            "redirect_uri": "myapp://oauth/callback",
            "client_id": "client-1",
            "code_verifier": Self.verifier
        ])

        XCTAssertEqual(token.accessToken, "at-1")
        XCTAssertEqual(token.refreshToken, "rt-1")
        XCTAssertEqual(token.tokenType, "bearer")
        XCTAssertEqual(token.expiresIn, 7200)
        XCTAssertEqual(token.scope, "read")
    }

    func testExchange_requestBodyMode_sendsSecretInBody() async throws {
        let flow = makeFlow(configuration(clientSecret: "s3cret", clientAuthentication: .requestBody))
        let captured = installTokenEndpoint()

        _ = try await flow.exchangeCode("code-1", for: try pendingRequest(flow))

        let sent = try XCTUnwrap(captured.value)
        XCTAssertNil(sent.value(forHTTPHeaderField: "Authorization"))
        let body = Self.formBody(of: sent)
        XCTAssertEqual(body["client_id"], "client-1")
        XCTAssertEqual(body["client_secret"], "s3cret")
        XCTAssertEqual(body["code_verifier"], Self.verifier)
    }

    func testExchange_basicMode_sendsSecretInHeader() async throws {
        let flow = makeFlow(configuration(clientSecret: "s3cret", clientAuthentication: .basicAuthorizationHeader))
        let captured = installTokenEndpoint()

        _ = try await flow.exchangeCode("code-1", for: try pendingRequest(flow))

        let sent = try XCTUnwrap(captured.value)
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Authorization"), basic("client-1", "s3cret"))
        let body = Self.formBody(of: sent)
        XCTAssertEqual(body["client_id"], "client-1")
        XCTAssertNil(body["client_secret"])
    }

    func testExchange_basicAllowingEmptySecret_sendsEmptyPassword() async throws {
        let flow = makeFlow(configuration(clientAuthentication: .basicAuthorizationHeaderAllowingEmptySecret))
        let captured = installTokenEndpoint()

        _ = try await flow.exchangeCode("code-1", for: try pendingRequest(flow))

        let sent = try XCTUnwrap(captured.value)
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Authorization"), basic("client-1", ""))
        XCTAssertNil(Self.formBody(of: sent)["client_secret"])
    }

    func testExchange_withoutPKCE_omitsVerifier() async throws {
        let flow = makeFlow(configuration(usesPKCE: false))
        let captured = installTokenEndpoint()

        _ = try await flow.exchangeCode("code-1", for: flow.makeAuthorizationRequest())

        XCTAssertNil(Self.formBody(of: try XCTUnwrap(captured.value))["code_verifier"])
    }

    // MARK: - Complete Authorization

    func testCompleteAuthorization_appliesTokensToAuth() async throws {
        let flow = makeFlow(configuration(clientSecret: "s3cret"))
        let request = try pendingRequest(flow)
        _ = installTokenEndpoint()
        let auth = Auth2Authentication()
        let before = Date()

        let token = try await flow.completeAuthorization(
            callbackURL: URL(string: "myapp://oauth/callback?code=code-1&state=state-123")!,
            request: request,
            auth: auth
        )

        XCTAssertEqual(token.accessToken, "at-1")
        XCTAssertEqual(auth.accessToken, "at-1")
        XCTAssertEqual(auth.refreshToken, "rt-1")
        XCTAssertEqual(auth.clientId, "client-1")
        XCTAssertEqual(auth.clientSecret, "s3cret")
        XCTAssertTrue(auth.isAuthorized)
        let expiresAt = try XCTUnwrap(auth.expiresAt)
        XCTAssertEqual(expiresAt.timeIntervalSince(before), 7200, accuracy: 5)
    }

    func testCompleteAuthorization_badCallback_neverHitsTokenEndpoint() async throws {
        let flow = makeFlow(configuration())
        let request = try pendingRequest(flow)
        let captured = installTokenEndpoint()
        let auth = Auth2Authentication()

        let error = await expectFailure {
            _ = try await flow.completeAuthorization(
                callbackURL: URL(string: "myapp://oauth/callback?code=code-1&state=forged")!,
                request: request,
                auth: auth
            )
        }

        XCTAssertEqual(error, .failed(reason: "OAuth state mismatch — possible CSRF."))
        XCTAssertNil(captured.value)
        XCTAssertNil(auth.accessToken)
    }

    // MARK: - Token Errors

    func testExchange_oauthErrorResponse() async throws {
        let flow = makeFlow(configuration())
        _ = installTokenEndpoint(status: 400, body: ["error": "invalid_grant", "error_description": "Code expired"])

        let request = try pendingRequest(flow)
        let error = await expectFailure { _ = try await flow.exchangeCode("code-1", for: request) }

        guard case let .failed(reason, json) = error else {
            return XCTFail("Unexpected \(String(describing: error))")
        }
        XCTAssertEqual(reason, "Code expired")
        XCTAssertEqual(json?["error"].string, "invalid_grant")
    }

    func testExchange_errorWithHTTP200_isAnError() async throws {
        // GitHub answers failed exchanges with 200 and an `error` field.
        let flow = makeFlow(configuration())
        _ = installTokenEndpoint(status: 200, body: ["error": "bad_verification_code"])

        let request = try pendingRequest(flow)
        let error = await expectFailure { _ = try await flow.exchangeCode("code-1", for: request) }

        guard case let .failed(reason, _) = error else {
            return XCTFail("Unexpected \(String(describing: error))")
        }
        XCTAssertEqual(reason, "bad_verification_code")
    }

    func testExchange_serverErrorAndRateLimit() async throws {
        let flow = makeFlow(configuration())
        let request = try pendingRequest(flow)

        _ = installTokenEndpoint(status: 503, body: [:])
        let serverError = await expectFailure { _ = try await flow.exchangeCode("code-1", for: request) }
        guard case .serverError = serverError else {
            return XCTFail("Unexpected \(String(describing: serverError))")
        }

        _ = installTokenEndpoint(status: 429, body: ["error": "slow_down"])
        let rateLimit = await expectFailure { _ = try await flow.exchangeCode("code-1", for: request) }
        guard case .rateLimit = rateLimit else {
            return XCTFail("Unexpected \(String(describing: rateLimit))")
        }
    }

    func testExchange_missingAccessToken() async throws {
        let flow = makeFlow(configuration())
        _ = installTokenEndpoint(status: 200, body: ["token_type": "bearer"])

        let request = try pendingRequest(flow)
        let error = await expectFailure { _ = try await flow.exchangeCode("code-1", for: request) }

        guard case let .failed(reason, _) = error else {
            return XCTFail("Unexpected \(String(describing: error))")
        }
        XCTAssertEqual(reason, "The token response did not include an access token.")
    }

    // MARK: - Presets

    func testXPreset() {
        let config = OAuth2AuthorizationCodeConfiguration.x(clientId: "x-client", redirectURI: Self.redirect)

        XCTAssertEqual(config.authorizeURL.absoluteString, "https://x.com/i/oauth2/authorize")
        XCTAssertEqual(config.tokenURL.absoluteString, "https://api.x.com/2/oauth2/token")
        XCTAssertEqual(config.clientAuthentication, .basicAuthorizationHeader)
        XCTAssertNil(config.clientSecret)
        XCTAssertEqual(config.scopeSeparator, " ")
        XCTAssertTrue(config.scopes.contains("offline.access"))
        XCTAssertTrue(config.usesPKCE)
    }

    func testGitHubPreset() {
        let config = OAuth2AuthorizationCodeConfiguration.gitHub(
            clientId: "gh", clientSecret: "secret", redirectURI: Self.redirect, scopes: ["read:user"]
        )

        XCTAssertEqual(config.authorizeURL.absoluteString, "https://github.com/login/oauth/authorize")
        XCTAssertEqual(config.tokenURL.absoluteString, "https://github.com/login/oauth/access_token")
        XCTAssertEqual(config.clientAuthentication, .requestBody)
        XCTAssertEqual(config.clientSecret, "secret")
    }

    func testMastodonPreset() throws {
        let config = try XCTUnwrap(OAuth2AuthorizationCodeConfiguration.mastodon(
            host: "@alice@Mastodon.Social", clientId: "m", clientSecret: "ms", redirectURI: Self.redirect
        ))

        XCTAssertEqual(config.authorizeURL.absoluteString, "https://mastodon.social/oauth/authorize")
        XCTAssertEqual(config.tokenURL.absoluteString, "https://mastodon.social/oauth/token")
        XCTAssertEqual(config.clientAuthentication, .requestBody)
        XCTAssertEqual(config.scopes, ["read:accounts", "read:follows", "write:follows"])

        XCTAssertNil(OAuth2AuthorizationCodeConfiguration.mastodon(
            host: "not a host", clientId: "m", clientSecret: nil, redirectURI: Self.redirect
        ))
    }
}

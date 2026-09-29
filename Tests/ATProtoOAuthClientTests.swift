import Alamofire
@testable import APWebAuthentication
import Foundation
import SwiftyJSON
import XCTest

@MainActor
final class ATProtoOAuthClientTests: XCTestCase {

    private var client: ATProtoOAuthClient!
    private var auth: ATProtoAuthentication!

    private let metadata = ATProtoAuthorizationServerMetadata(
        issuer: "https://bsky.social",
        authorizationEndpoint: URL(string: "https://bsky.social/oauth/authorize")!,
        tokenEndpoint: URL(string: "https://bsky.social/oauth/token")!,
        pushedAuthorizationRequestEndpoint: URL(string: "https://bsky.social/oauth/par")!,
        revocationEndpoint: URL(string: "https://bsky.social/oauth/revoke")!
    )

    override func setUp() async throws {
        try await super.setUp()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        client = ATProtoOAuthClient(session: Session(configuration: configuration))

        auth = ATProtoAuthentication()
        auth.clientId = "https://app.example.com/oauth/client-metadata.json"
        auth.redirectURL = "com.example.app:/oauth/callback"
        auth.dpopKey = DPoPKey()
    }

    override func tearDown() async throws {
        MockURLProtocol.handler = nil
        try await super.tearDown()
    }

    // MARK: - Pure Helpers

    func testNormalizeHandle() {
        XCTAssertEqual(ATProtoOAuthClient.normalizeHandle("  @Alice.bsky.social "), "alice.bsky.social")
        XCTAssertEqual(ATProtoOAuthClient.normalizeHandle("alice"), "alice.bsky.social")
        XCTAssertEqual(ATProtoOAuthClient.normalizeHandle("https://bsky.app/profile/alice.example.com/"), "alice.example.com")
        XCTAssertEqual(ATProtoOAuthClient.normalizeHandle("did:plc:abc"), "did:plc:abc")
        XCTAssertEqual(ATProtoOAuthClient.normalizeHandle("   "), "")
    }

    func testCodeChallenge_matchesRFC7636Vector() {
        XCTAssertEqual(
            ATProtoOAuthClient.codeChallenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        )
    }

    func testRandomToken_is43URLSafeCharacters() {
        let token = ATProtoOAuthClient.randomToken()
        XCTAssertEqual(token.count, 43)
        XCTAssertNil(token.rangeOfCharacter(from: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted))
        XCTAssertNotEqual(token, ATProtoOAuthClient.randomToken())
    }

    func testOrigin_dropsPathAndDefaultPort() {
        XCTAssertEqual(ATProtoOAuthClient.origin(of: "https://BSKY.social:443/oauth/x?y=1"), "https://bsky.social")
        XCTAssertEqual(ATProtoOAuthClient.origin(of: "https://pds.example.com:8443/"), "https://pds.example.com:8443")
    }

    func testPDSEndpoint_findsAtprotoService() {
        let document = JSON([
            "id": "did:plc:abc",
            "service": [
                ["id": "#other", "type": "Something", "serviceEndpoint": "https://other.example.com"],
                ["id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "https://morel.us-east.host.bsky.network"]
            ]
        ])
        XCTAssertEqual(ATProtoOAuthClient.pdsEndpoint(in: document)?.absoluteString, "https://morel.us-east.host.bsky.network")
        XCTAssertNil(ATProtoOAuthClient.pdsEndpoint(in: JSON(["service": []])))
    }

    // MARK: - Discovery

    func testResolveIdentity_walksHandleToAuthorizationServer() async throws {
        MockURLProtocol.handler = { request in
            let url = request.url!.absoluteString
            if url.hasPrefix("https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle") {
                XCTAssertTrue(url.contains("handle=alice.bsky.social"))
                return MockURLProtocol.response(for: request, status: 200, body: Self.data(["did": "did:plc:abc"]))
            }
            if url == "https://plc.directory/did:plc:abc" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.didDocument(handles: ["Alice.bsky.social"]))
            }
            if url == "https://pds.example.com/.well-known/oauth-protected-resource" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.data(["authorization_servers": ["https://bsky.social"]]))
            }
            return MockURLProtocol.response(for: request, status: 404)
        }

        let identity = try await client.resolveIdentity(handle: "alice.bsky.social")
        XCTAssertEqual(identity.did, "did:plc:abc")
        XCTAssertEqual(identity.handle, "alice.bsky.social", "case-insensitive match, normalised")
        XCTAssertEqual(identity.pdsURL.absoluteString, "https://pds.example.com")
        XCTAssertEqual(identity.authorizationServer.absoluteString, "https://bsky.social")
    }

    func testResolveIdentity_rejectsHandleTheDIDDocumentDoesNotClaim() async {
        MockURLProtocol.handler = { request in
            let url = request.url!.absoluteString
            if url.hasPrefix("https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle") {
                return MockURLProtocol.response(for: request, status: 200, body: Self.data(["did": "did:plc:abc"]))
            }
            if url == "https://plc.directory/did:plc:abc" {
                // The DID's owner only ever claimed their real handle.
                return MockURLProtocol.response(for: request, status: 200, body: Self.didDocument(handles: ["alice.bsky.social"]))
            }
            return MockURLProtocol.response(for: request, status: 404)
        }

        do {
            _ = try await client.resolveIdentity(handle: "impostor.example.com")
            XCTFail("Expected failure")
        } catch {
            guard case .failed(let reason, _) = error else { return XCTFail("Unexpected error \(error)") }
            XCTAssertTrue(reason?.contains("impostor.example.com") ?? false)
        }
    }

    func testResolveIdentity_fromDIDAdoptsTheDocumentsHandleWhenItResolvesBack() async throws {
        MockURLProtocol.handler = { request in
            let url = request.url!.absoluteString
            if url == "https://plc.directory/did:plc:abc" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.didDocument(handles: ["alice.bsky.social"]))
            }
            if url.hasPrefix("https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle") {
                XCTAssertTrue(url.contains("handle=alice.bsky.social"))
                return MockURLProtocol.response(for: request, status: 200, body: Self.data(["did": "did:plc:abc"]))
            }
            if url == "https://pds.example.com/.well-known/oauth-protected-resource" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.data(["authorization_servers": ["https://bsky.social"]]))
            }
            XCTFail("Unexpected request \(url)")
            return MockURLProtocol.response(for: request, status: 404)
        }

        let identity = try await client.resolveIdentity(handle: "did:plc:abc")
        XCTAssertEqual(identity.handle, "alice.bsky.social")
    }

    func testResolveIdentity_fromDIDRejectsHandleThatResolvesElsewhere() async {
        MockURLProtocol.handler = { request in
            let url = request.url!.absoluteString
            if url == "https://plc.directory/did:plc:abc" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.didDocument(handles: ["alice.bsky.social"]))
            }
            if url.hasPrefix("https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle") {
                return MockURLProtocol.response(for: request, status: 200, body: Self.data(["did": "did:plc:someone-else"]))
            }
            return MockURLProtocol.response(for: request, status: 404)
        }

        do {
            _ = try await client.resolveIdentity(handle: "did:plc:abc")
            XCTFail("Expected failure")
        } catch {
            guard case .failed(let reason, _) = error else { return XCTFail("Unexpected error \(error)") }
            XCTAssertTrue(reason?.contains("alice.bsky.social") ?? false)
        }
    }

    func testResolveIdentity_fromDIDWithoutHandleLeavesItNil() async throws {
        MockURLProtocol.handler = { request in
            let url = request.url!.absoluteString
            if url == "https://plc.directory/did:plc:abc" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.didDocument(handles: []))
            }
            if url == "https://pds.example.com/.well-known/oauth-protected-resource" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.data(["authorization_servers": ["https://bsky.social"]]))
            }
            XCTFail("Unexpected request \(url)")
            return MockURLProtocol.response(for: request, status: 404)
        }

        let identity = try await client.resolveIdentity(handle: "did:plc:abc")
        XCTAssertNil(identity.handle)
    }

    func testHandles_readsOnlyATURIsFromAlsoKnownAs() {
        let document = JSON(["alsoKnownAs": ["at://Alice.bsky.social", "https://alice.example.com", "at://", "at://alice.example.com"]])
        XCTAssertEqual(ATProtoOAuthClient.handles(in: document), ["alice.bsky.social", "alice.example.com"])
        XCTAssertEqual(ATProtoOAuthClient.handles(in: JSON([:])), [])
    }

    func testDIDDocumentURL_coversPLCAndDIDWeb() {
        XCTAssertEqual(ATProtoOAuthClient.didDocumentURL(for: "did:plc:abc")?.absoluteString, "https://plc.directory/did:plc:abc")
        XCTAssertEqual(ATProtoOAuthClient.didDocumentURL(for: "did:web:example.com")?.absoluteString, "https://example.com/.well-known/did.json")
        XCTAssertEqual(ATProtoOAuthClient.didDocumentURL(for: "did:web:example.com:users:alice")?.absoluteString, "https://example.com/users/alice/did.json")
        XCTAssertEqual(ATProtoOAuthClient.didDocumentURL(for: "did:web:example.com%3A8443")?.absoluteString, "https://example.com:8443/.well-known/did.json")
        XCTAssertNil(ATProtoOAuthClient.didDocumentURL(for: "did:web:"))
        XCTAssertNil(ATProtoOAuthClient.didDocumentURL(for: "did:web:example.com::alice"))
        XCTAssertNil(ATProtoOAuthClient.didDocumentURL(for: "did:key:z6Mk"))
    }

    func testResolvePDS_didWebWithPathSegments() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/users/alice/did.json")
            return MockURLProtocol.response(for: request, status: 200, body: Self.data([
                "service": [["id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "https://pds.example.com"]]
            ]))
        }

        let pds = try await client.resolvePDS(did: "did:web:example.com:users:alice")
        XCTAssertEqual(pds.absoluteString, "https://pds.example.com")
    }

    func testResolveHandle_unknownHandleThrowsNotFound() async {
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 400, body: Self.data(["error": "InvalidRequest", "message": "Unable to resolve handle"]))
        }

        do {
            _ = try await client.resolveHandle("nobody.bsky.social")
            XCTFail("Expected failure")
        } catch {
            guard case .failed(let reason, _) = error else { return XCTFail("Unexpected error \(error)") }
            XCTAssertEqual(reason, "Unable to resolve handle")
        }
    }

    func testAuthorizationServerMetadata_rejectsIssuerMismatch() async {
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 200, body: Self.serverMetadata(["issuer": "https://evil.example.com"]))
        }

        do {
            _ = try await client.authorizationServerMetadata(issuer: URL(string: "https://bsky.social")!)
            XCTFail("Expected failure")
        } catch {
            guard case .failed = error else { return XCTFail("Unexpected error \(error)") }
        }
    }

    func testAuthorizationServerMetadata_parsesDocument() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://bsky.social/.well-known/oauth-authorization-server")
            return MockURLProtocol.response(for: request, status: 200, body: Self.serverMetadata())
        }

        let parsed = try await client.authorizationServerMetadata(issuer: URL(string: "https://bsky.social/")!)
        XCTAssertEqual(parsed, metadata)
    }

    func testAuthorizationServerMetadata_toleratesMissingRevocationEndpointAndScopesList() async throws {
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 200, body: Self.serverMetadata(["revocation_endpoint": NSNull(), "scopes_supported": NSNull()]))
        }

        let parsed = try await client.authorizationServerMetadata(issuer: URL(string: "https://bsky.social")!)
        XCTAssertNil(parsed.revocationEndpoint)
    }

    func testAuthorizationServerMetadata_rejectsServersMissingRequiredCapabilities() async {
        // Each entry removes or breaks one capability the login relies on.
        let broken: [(String, [String: Any], String)] = [
            ("no code flow", ["response_types_supported": ["token"]], "authorization code"),
            ("no refresh", ["grant_types_supported": ["authorization_code"]], "refresh"),
            ("no PKCE", ["code_challenge_methods_supported": ["plain"]], "PKCE"),
            ("no public clients", ["token_endpoint_auth_methods_supported": ["private_key_jwt"]], "public clients"),
            ("no ES256", ["dpop_signing_alg_values_supported": ["RS256"]], "ES256"),
            ("no atproto scope", ["scopes_supported": ["openid"]], "atproto"),
            ("PAR optional", ["require_pushed_authorization_requests": false], "pushed authorization"),
            ("no iss", ["authorization_response_iss_parameter_supported": false], "identify itself"),
            ("no metadata documents", ["client_id_metadata_document_supported": false], "client metadata"),
            ("issuer with path", ["issuer": "https://bsky.social/oauth"], "issuer"),
            ("issuer with port", ["issuer": "https://bsky.social:8443"], "issuer"),
            ("http issuer", ["issuer": "http://bsky.social"], "issuer")
        ]

        for (name, overrides, expectedFragment) in broken {
            let body = Self.serverMetadata(overrides)
            MockURLProtocol.handler = { request in
                MockURLProtocol.response(for: request, status: 200, body: body)
            }
            do {
                _ = try await client.authorizationServerMetadata(issuer: URL(string: "https://bsky.social")!)
                XCTFail("\(name): expected failure")
            } catch {
                guard case .failed(let reason, _) = error else { return XCTFail("\(name): unexpected error \(error)") }
                XCTAssertTrue(reason?.localizedCaseInsensitiveContains(expectedFragment) ?? false, "\(name): \(reason ?? "nil")")
            }
        }
    }

    // MARK: - PAR

    func testBeginAuthorization_retriesOnceWithServerNonce() async throws {
        let proofs = LockedResult<[String]>(initial: [])

        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://bsky.social/oauth/par")
            XCTAssertEqual(request.httpMethod, "POST")
            let proof = request.value(forHTTPHeaderField: "DPoP") ?? ""
            proofs.value.append(proof)

            if proofs.value.count == 1 {
                let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: [
                    "Content-Type": "application/json",
                    "DPoP-Nonce": "server-nonce-1"
                ])!
                return (response, Self.data(["error": "use_dpop_nonce", "error_description": "Authorization server requires nonce in DPoP proof"]))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: [
                "Content-Type": "application/json",
                "DPoP-Nonce": "server-nonce-2"
            ])!
            return (response, Self.data(["request_uri": "urn:ietf:params:oauth:request_uri:abc", "expires_in": 60]))
        }

        let request = try await client.beginAuthorization(auth: auth, metadata: metadata, loginHint: "alice.bsky.social", expectedDID: "did:plc:abc", state: "state-1")

        XCTAssertEqual(proofs.value.count, 2)
        XCTAssertNil(Self.claims(of: proofs.value[0])["nonce"])
        XCTAssertEqual(Self.claims(of: proofs.value[1])["nonce"] as? String, "server-nonce-1")
        XCTAssertEqual(Self.claims(of: proofs.value[1])["htm"] as? String, "POST")
        XCTAssertEqual(Self.claims(of: proofs.value[1])["htu"] as? String, "https://bsky.social/oauth/par")

        XCTAssertEqual(auth.authorizationServerNonce, "server-nonce-2")
        XCTAssertEqual(request.state, "state-1")
        XCTAssertEqual(request.expectedDID, "did:plc:abc")
        XCTAssertEqual(request.codeVerifier.count, 43)

        let query = request.authorizationURL.parameters
        XCTAssertTrue(request.authorizationURL.absoluteString.hasPrefix("https://bsky.social/oauth/authorize?"))
        XCTAssertEqual(query["client_id"], auth.clientId)
        XCTAssertEqual(query["request_uri"], "urn:ietf:params:oauth:request_uri:abc")
        XCTAssertEqual(query.count, 2)
    }

    func testBeginAuthorization_surfacesServerError() async {
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 400, body: Self.data(["error": "invalid_client_metadata", "error_description": "Invalid redirect_uri"]))
        }

        do {
            _ = try await client.beginAuthorization(auth: auth, metadata: metadata)
            XCTFail("Expected failure")
        } catch {
            guard case .failed(let reason, _) = error else { return XCTFail("Unexpected error \(error)") }
            XCTAssertEqual(reason, "Invalid redirect_uri")
        }
    }

    // MARK: - Token Exchange

    private func pendingRequest(expectedDID: String?) -> ATProtoAuthorizationRequest {
        ATProtoAuthorizationRequest(
            authorizationURL: metadata.authorizationEndpoint,
            state: "state-1",
            codeVerifier: "verifier",
            metadata: metadata,
            expectedDID: expectedDID
        )
    }

    nonisolated private static func tokenBody(sub: String = "did:plc:abc", scope: String? = "atproto transition:generic", tokenType: String = "DPoP") -> Data {
        var body: [String: Any] = [
            "access_token": "access-1",
            "refresh_token": "refresh-1",
            "token_type": tokenType,
            "expires_in": 300,
            "sub": sub
        ]
        if let scope { body["scope"] = scope }
        return Self.data(body)
    }

    func testCompleteAuthorization_stateMismatchThrows() async {
        let callback = URL(string: "com.example.app:/oauth/callback?code=c1&state=other&iss=https://bsky.social")!
        do {
            try await client.completeAuthorization(callbackURL: callback, request: pendingRequest(expectedDID: nil), auth: auth)
            XCTFail("Expected failure")
        } catch {
            guard case .failed(let reason, _) = error else { return XCTFail("Unexpected error \(error)") }
            XCTAssertTrue(reason?.contains("state") ?? false)
        }
    }

    func testCompleteAuthorization_issuerMismatchThrows() async {
        let callback = URL(string: "com.example.app:/oauth/callback?code=c1&state=state-1&iss=https://evil.example.com")!
        do {
            try await client.completeAuthorization(callbackURL: callback, request: pendingRequest(expectedDID: nil), auth: auth)
            XCTFail("Expected failure")
        } catch {
            guard case .failed = error else { return XCTFail("Unexpected error \(error)") }
        }
    }

    func testCompleteAuthorization_accessDeniedIsCanceled() async {
        let callback = URL(string: "com.example.app:/oauth/callback?error=access_denied&state=state-1")!
        do {
            try await client.completeAuthorization(callbackURL: callback, request: pendingRequest(expectedDID: nil), auth: auth)
            XCTFail("Expected failure")
        } catch {
            guard case .canceled = error else { return XCTFail("Unexpected error \(error)") }
        }
    }

    func testCompleteAuthorization_exchangesCodeAndBindsSession() async throws {
        let tokenProof = LockedResult<String?>(initial: nil)

        MockURLProtocol.handler = { request in
            let url = request.url!.absoluteString
            if url == "https://bsky.social/oauth/token" {
                tokenProof.value = request.value(forHTTPHeaderField: "DPoP")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
                return MockURLProtocol.response(for: request, status: 200, body: Self.tokenBody())
            }
            if url == "https://plc.directory/did:plc:abc" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.data([
                    "service": [["id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "https://pds.example.com"]]
                ]))
            }
            return MockURLProtocol.response(for: request, status: 404)
        }

        let callback = URL(string: "com.example.app:/oauth/callback?code=c1&state=state-1&iss=https://bsky.social")!
        try await client.completeAuthorization(callbackURL: callback, request: pendingRequest(expectedDID: "did:plc:abc"), auth: auth)

        XCTAssertEqual(auth.accessToken, "access-1")
        XCTAssertEqual(auth.refreshToken, "refresh-1")
        XCTAssertEqual(auth.did, "did:plc:abc")
        XCTAssertEqual(auth.pdsURL?.absoluteString, "https://pds.example.com")
        XCTAssertEqual(auth.issuer, "https://bsky.social")
        XCTAssertEqual(auth.tokenEndpoint, metadata.tokenEndpoint)
        XCTAssertEqual(auth.revocationEndpoint, metadata.revocationEndpoint)
        XCTAssertEqual(auth.scope, "atproto transition:generic")
        XCTAssertTrue(auth.isAuthorized)

        let claims = Self.claims(of: try XCTUnwrap(tokenProof.value))
        XCTAssertEqual(claims["htu"] as? String, "https://bsky.social/oauth/token")
        XCTAssertNil(claims["ath"], "Token endpoint proofs carry no access token hash")
    }

    func testCompleteAuthorization_entrywayLoginVerifiesAccountIssuer() async throws {
        MockURLProtocol.handler = { request in
            let url = request.url!.absoluteString
            if url == "https://bsky.social/oauth/token" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.tokenBody())
            }
            if url == "https://plc.directory/did:plc:abc" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.didDocument(handles: ["alice.bsky.social"]))
            }
            if url == "https://pds.example.com/.well-known/oauth-protected-resource" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.data(["authorization_servers": ["https://other-entryway.example.com"]]))
            }
            return MockURLProtocol.response(for: request, status: 404)
        }

        let callback = URL(string: "com.example.app:/oauth/callback?code=c1&state=state-1")!
        do {
            try await client.completeAuthorization(callbackURL: callback, request: pendingRequest(expectedDID: nil), auth: auth)
            XCTFail("Expected failure")
        } catch {
            guard case .failed = error else { return XCTFail("Unexpected error \(error)") }
        }
        XCTAssertNil(auth.accessToken, "A failed binding must not leave tokens behind")
    }

    func testCompleteAuthorization_entrywayLoginAdoptsHandleFromDIDDocument() async throws {
        MockURLProtocol.handler = { request in
            let url = request.url!.absoluteString
            if url == "https://bsky.social/oauth/token" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.tokenBody())
            }
            if url == "https://plc.directory/did:plc:abc" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.didDocument(handles: ["alice.bsky.social"]))
            }
            if url == "https://pds.example.com/.well-known/oauth-protected-resource" {
                return MockURLProtocol.response(for: request, status: 200, body: Self.data(["authorization_servers": ["https://bsky.social"]]))
            }
            return MockURLProtocol.response(for: request, status: 404)
        }

        let callback = URL(string: "com.example.app:/oauth/callback?code=c1&state=state-1")!
        try await client.completeAuthorization(callbackURL: callback, request: pendingRequest(expectedDID: nil), auth: auth)

        XCTAssertEqual(auth.handle, "alice.bsky.social")
        XCTAssertTrue(auth.isAuthorized)
    }

    func testCompleteAuthorization_subMismatchThrows() async {
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 200, body: Self.tokenBody(sub: "did:plc:someone-else"))
        }

        let callback = URL(string: "com.example.app:/oauth/callback?code=c1&state=state-1")!
        do {
            try await client.completeAuthorization(callbackURL: callback, request: pendingRequest(expectedDID: "did:plc:abc"), auth: auth)
            XCTFail("Expected failure")
        } catch {
            guard case .failed = error else { return XCTFail("Unexpected error \(error)") }
        }
        XCTAssertNil(auth.accessToken)
    }

    func testCompleteAuthorization_rejectsNonDPoPToken() async {
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 200, body: Self.tokenBody(tokenType: "Bearer"))
        }

        let callback = URL(string: "com.example.app:/oauth/callback?code=c1&state=state-1")!
        do {
            try await client.completeAuthorization(callbackURL: callback, request: pendingRequest(expectedDID: "did:plc:abc"), auth: auth)
            XCTFail("Expected failure")
        } catch {
            guard case .failed = error else { return XCTFail("Unexpected error \(error)") }
        }
    }

    func testCompleteAuthorization_rejectsMissingAtprotoScope() async {
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 200, body: Self.tokenBody(scope: "transition:generic"))
        }

        let callback = URL(string: "com.example.app:/oauth/callback?code=c1&state=state-1")!
        do {
            try await client.completeAuthorization(callbackURL: callback, request: pendingRequest(expectedDID: "did:plc:abc"), auth: auth)
            XCTFail("Expected failure")
        } catch {
            guard case .failed = error else { return XCTFail("Unexpected error \(error)") }
        }
    }

    // MARK: - Refresh

    private func primeSession() {
        auth.did = "did:plc:abc"
        auth.accessToken = "old-access"
        auth.refreshToken = "old-refresh"
        auth.tokenEndpoint = metadata.tokenEndpoint
        auth.issuer = metadata.issuer
    }

    func testRefresh_rotatesTokens() async throws {
        primeSession()
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://bsky.social/oauth/token")
            return MockURLProtocol.response(for: request, status: 200, body: Self.data([
                "access_token": "new-access",
                "refresh_token": "new-refresh",
                "token_type": "DPoP",
                "expires_in": 300,
                "scope": "atproto transition:generic",
                "sub": "did:plc:abc"
            ]))
        }

        try await client.refresh(auth: auth)

        XCTAssertEqual(auth.accessToken, "new-access")
        XCTAssertEqual(auth.refreshToken, "new-refresh")
        XCTAssertFalse(auth.isAccessTokenExpired)
    }

    func testRefresh_invalidGrantThrowsSessionExpired() async {
        primeSession()
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 400, body: Self.data(["error": "invalid_grant", "error_description": "Refresh token expired"]))
        }

        do {
            try await client.refresh(auth: auth)
            XCTFail("Expected failure")
        } catch {
            guard case .sessionExpired = error else { return XCTFail("Unexpected error \(error)") }
        }
        XCTAssertEqual(auth.accessToken, "old-access", "The client leaves clearing tokens to its caller")
    }

    func testRefresh_serverErrorIsNotSessionExpired() async {
        primeSession()
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 503, body: Self.data(["error": "server_error"]))
        }

        do {
            try await client.refresh(auth: auth)
            XCTFail("Expected failure")
        } catch {
            guard case .serverError = error else { return XCTFail("Unexpected error \(error)") }
        }
    }

    func testRefresh_withoutRefreshTokenThrowsSessionExpired() async {
        auth.tokenEndpoint = metadata.tokenEndpoint
        do {
            try await client.refresh(auth: auth)
            XCTFail("Expected failure")
        } catch {
            guard case .sessionExpired = error else { return XCTFail("Unexpected error \(error)") }
        }
    }

    // MARK: - Revocation

    func testRevoke_postsBothTokensWithDPoPAndHints() async {
        primeSession()
        auth.revocationEndpoint = metadata.revocationEndpoint
        let posts = LockedResult<[[String: String]]>(initial: [])

        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://bsky.social/oauth/revoke")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertNotNil(request.value(forHTTPHeaderField: "DPoP"))
            posts.value.append(Self.formBody(of: request))
            return MockURLProtocol.response(for: request, status: 200, body: Data("{}".utf8))
        }

        let revoked = await client.revoke(auth: auth)

        XCTAssertEqual(revoked, 2)
        XCTAssertEqual(posts.value.count, 2)
        XCTAssertEqual(posts.value[0]["token"], "old-refresh")
        XCTAssertEqual(posts.value[0]["token_type_hint"], "refresh_token")
        XCTAssertEqual(posts.value[0]["client_id"], auth.clientId)
        XCTAssertEqual(posts.value[1]["token"], "old-access")
        XCTAssertEqual(posts.value[1]["token_type_hint"], "access_token")
    }

    func testRevoke_retriesOnceOnNonceChallenge() async {
        primeSession()
        auth.refreshToken = nil
        auth.revocationEndpoint = metadata.revocationEndpoint
        let attempts = LockedResult<Int>(initial: 0)

        MockURLProtocol.handler = { request in
            attempts.value += 1
            if attempts.value == 1 {
                let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: [
                    "Content-Type": "application/json", "DPoP-Nonce": "n1"
                ])!
                return (response, Self.data(["error": "use_dpop_nonce"]))
            }
            return MockURLProtocol.response(for: request, status: 200, body: Data("{}".utf8))
        }

        let revoked = await client.revoke(auth: auth)
        XCTAssertEqual(revoked, 1)
        XCTAssertEqual(attempts.value, 2)
    }

    func testRevoke_withoutEndpointMakesNoRequests() async {
        primeSession()
        auth.revocationEndpoint = nil
        MockURLProtocol.handler = { request in
            XCTFail("Unexpected request \(request.url!)")
            return MockURLProtocol.response(for: request, status: 500)
        }

        let revoked = await client.revoke(auth: auth)
        XCTAssertEqual(revoked, 0)
    }

    func testRevoke_serverFailureIsSwallowedAndTokensStayLocal() async {
        primeSession()
        auth.revocationEndpoint = metadata.revocationEndpoint
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 503, body: Self.data(["error": "server_error"]))
        }

        let revoked = await client.revoke(auth: auth)
        XCTAssertEqual(revoked, 0)
        XCTAssertEqual(auth.accessToken, "old-access", "clearing the session is the caller's job")
    }

    // MARK: - Helpers

    /// A conforming `oauth-authorization-server` document, with `overrides`
    /// applied on top (`NSNull` removes a key).
    nonisolated private static func serverMetadata(_ overrides: [String: Any] = [:]) -> Data {
        var document: [String: Any] = [
            "issuer": "https://bsky.social",
            "authorization_endpoint": "https://bsky.social/oauth/authorize",
            "token_endpoint": "https://bsky.social/oauth/token",
            "pushed_authorization_request_endpoint": "https://bsky.social/oauth/par",
            "revocation_endpoint": "https://bsky.social/oauth/revoke",
            "response_types_supported": ["code"],
            "grant_types_supported": ["authorization_code", "refresh_token"],
            "code_challenge_methods_supported": ["S256"],
            "token_endpoint_auth_methods_supported": ["none", "private_key_jwt"],
            "token_endpoint_auth_signing_alg_values_supported": ["ES256"],
            "scopes_supported": ["atproto", "transition:generic"],
            "authorization_response_iss_parameter_supported": true,
            "require_pushed_authorization_requests": true,
            "dpop_signing_alg_values_supported": ["ES256"],
            "client_id_metadata_document_supported": true
        ]
        for (key, value) in overrides {
            if value is NSNull {
                document.removeValue(forKey: key)
            } else {
                document[key] = value
            }
        }
        return data(document)
    }

    /// Reads a form-encoded POST body back out of the request the mock
    /// transport receives; Foundation hands it over as a stream.
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
        return URL.parseFormURLEncoded(String(decoding: data, as: UTF8.self))
            .reduce(into: [:]) { $0[$1.0] = $1.1 }
    }

    nonisolated private static func didDocument(handles: [String], pds: String = "https://pds.example.com") -> Data {
        data([
            "alsoKnownAs": handles.map { "at://\($0)" },
            "service": [["id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": pds]]
        ])
    }

    nonisolated private static func data(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    nonisolated private static func claims(of proof: String) -> [String: Any] {
        let parts = proof.split(separator: ".").map(String.init)
        guard parts.count == 3, let data = base64URLDecode(parts[1]) else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}

/// Minimal lock box for values captured from the mock transport's queue.
final class LockedResult<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(initial: T) { _value = initial }
    var value: T {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}

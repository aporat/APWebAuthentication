@testable import APWebAuthentication
import SwiftyJSON
import XCTest

@MainActor
final class ATProtoAuthenticationTests: XCTestCase {

    var auth: ATProtoAuthentication!

    override func setUp() async throws {
        try await super.setUp()
        auth = ATProtoAuthentication()
        auth.accountIdentifier = UUID().uuidString
    }

    override func tearDown() async throws {
        await auth.delete()
        try await super.tearDown()
    }

    func testIsAuthorized_requiresTokenDIDAndKey() {
        XCTAssertFalse(auth.isAuthorized)

        auth.accessToken = "token"
        XCTAssertFalse(auth.isAuthorized)

        auth.did = "did:plc:abc"
        XCTAssertFalse(auth.isAuthorized)

        auth.dpopKey = DPoPKey()
        XCTAssertTrue(auth.isAuthorized)
    }

    func testIsAccessTokenExpired_usesThirtySecondMargin() {
        XCTAssertFalse(auth.isAccessTokenExpired)

        auth.expiresAt = Date().addingTimeInterval(10)
        XCTAssertTrue(auth.isAccessTokenExpired)

        auth.expiresAt = Date().addingTimeInterval(120)
        XCTAssertFalse(auth.isAccessTokenExpired)
    }

    func testApply_updatesTokensAndKeepsRefreshTokenWhenOmitted() {
        auth.refreshToken = "old-refresh"
        auth.apply(ATProtoTokenResponse(accessToken: "a1", refreshToken: nil, tokenType: "DPoP", expiresIn: 300, scope: "atproto", sub: "did:plc:abc"))

        XCTAssertEqual(auth.accessToken, "a1")
        XCTAssertEqual(auth.refreshToken, "old-refresh")
        XCTAssertEqual(auth.did, "did:plc:abc")
        XCTAssertEqual(auth.scope, "atproto")
        XCTAssertNotNil(auth.expiresAt)

        auth.apply(ATProtoTokenResponse(accessToken: "a2", refreshToken: "r2", tokenType: "DPoP", expiresIn: nil, scope: nil, sub: nil))
        XCTAssertEqual(auth.accessToken, "a2")
        XCTAssertEqual(auth.refreshToken, "r2")
        XCTAssertNil(auth.expiresAt)
        XCTAssertEqual(auth.did, "did:plc:abc")
    }

    func testConfigure_readsClientOptions() {
        auth.configure(with: JSON([
            "client_id": "https://example.com/oauth/client-metadata.json",
            "redirect_url": "com.example:/oauth/callback",
            "scope": "atproto"
        ]))

        XCTAssertEqual(auth.clientId, "https://example.com/oauth/client-metadata.json")
        XCTAssertEqual(auth.redirectURL, "com.example:/oauth/callback")
        XCTAssertEqual(auth.scope, "atproto")
    }

    func testSaveAndLoad_roundTripsSession() async throws {
        // A hostless test bundle has no Keychain access group; only run the
        // round trip where the Keychain actually works.
        let probe = "probe-" + UUID().uuidString
        do {
            try KeychainStore.save(Data([1]), account: probe, category: "atproto-test")
            try KeychainStore.delete(account: probe, category: "atproto-test")
        } catch {
            throw XCTSkip("Keychain unavailable in this test environment: \(error)")
        }

        let key = DPoPKey()
        auth.clientId = "https://example.com/client-metadata.json"
        auth.redirectURL = "com.example:/callback"
        auth.did = "did:plc:abc"
        auth.handle = "alice.bsky.social"
        auth.pdsURL = URL(string: "https://pds.example.com")
        auth.issuer = "https://bsky.social"
        auth.tokenEndpoint = URL(string: "https://bsky.social/oauth/token")
        auth.revocationEndpoint = URL(string: "https://bsky.social/oauth/revoke")
        auth.accessToken = "access"
        auth.refreshToken = "refresh"
        auth.expiresAt = Date(timeIntervalSince1970: 1_800_000_000)
        auth.dpopKey = key
        auth.authorizationServerNonce = "transient"
        await auth.save()

        let restored = ATProtoAuthentication()
        restored.accountIdentifier = auth.accountIdentifier
        await restored.load()

        XCTAssertEqual(restored.clientId, auth.clientId)
        XCTAssertEqual(restored.redirectURL, auth.redirectURL)
        XCTAssertEqual(restored.did, "did:plc:abc")
        XCTAssertEqual(restored.handle, "alice.bsky.social")
        XCTAssertEqual(restored.pdsURL, auth.pdsURL)
        XCTAssertEqual(restored.issuer, "https://bsky.social")
        XCTAssertEqual(restored.tokenEndpoint, auth.tokenEndpoint)
        XCTAssertEqual(restored.revocationEndpoint, auth.revocationEndpoint)
        XCTAssertEqual(restored.accessToken, "access")
        XCTAssertEqual(restored.refreshToken, "refresh")
        XCTAssertEqual(restored.expiresAt, auth.expiresAt)
        XCTAssertEqual(restored.dpopKey?.thumbprint, key.thumbprint)
        XCTAssertNil(restored.authorizationServerNonce)
        XCTAssertTrue(restored.isAuthorized)
    }

    func testDelete_clearsSession() async {
        auth.accessToken = "access"
        auth.did = "did:plc:abc"
        auth.dpopKey = DPoPKey()
        auth.revocationEndpoint = URL(string: "https://bsky.social/oauth/revoke")
        await auth.delete()

        XCTAssertNil(auth.revocationEndpoint)
        XCTAssertNil(auth.accessToken)
        XCTAssertNil(auth.did)
        XCTAssertNil(auth.dpopKey)
        XCTAssertFalse(auth.isAuthorized)
    }

    func testInvalidateTokens_keepsClientConfiguration() {
        auth.clientId = "https://example.com/client-metadata.json"
        auth.accessToken = "access"
        auth.refreshToken = "refresh"
        auth.invalidateTokens()

        XCTAssertNil(auth.accessToken)
        XCTAssertNil(auth.refreshToken)
        XCTAssertEqual(auth.clientId, "https://example.com/client-metadata.json")
    }
}

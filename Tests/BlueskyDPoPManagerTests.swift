@testable import APWebAuthentication
import CryptoKit
import XCTest

final class BlueskyDPoPManagerTests: XCTestCase {

    func testMakeProofReturnsThreeParts() throws {
        let privateKey = P256.Signing.PrivateKey()
        let url = URL(string: "https://bsky.social/xrpc/app.bsky.actor.getProfile")!

        let proof = try BlueskyDPoPManager.makeProof(
            privateKey: privateKey,
            method: "GET",
            url: url
        )

        let parts = proof.split(separator: ".")
        XCTAssertEqual(parts.count, 3, "DPoP JWT must have exactly 3 dot-separated parts")
    }

    func testMakeProofWithNonce() throws {
        let privateKey = P256.Signing.PrivateKey()
        let url = URL(string: "https://bsky.social/xrpc/com.atproto.server.refreshSession")!

        let proof = try BlueskyDPoPManager.makeProof(
            privateKey: privateKey,
            method: "POST",
            url: url,
            nonce: "server-nonce-value"
        )

        XCTAssertFalse(proof.isEmpty)
        let parts = proof.split(separator: ".")
        XCTAssertEqual(parts.count, 3)
    }

    func testPublicKeyJWKContainsRequiredFields() throws {
        let privateKey = P256.Signing.PrivateKey()
        let jwk = try BlueskyDPoPManager.publicKeyJWK(from: privateKey)

        XCTAssertEqual(jwk["kty"], "EC")
        XCTAssertEqual(jwk["crv"], "P-256")
        XCTAssertNotNil(jwk["x"])
        XCTAssertNotNil(jwk["y"])
    }

    func testCodeChallengeIsBase64URL() {
        let verifier = BlueskyAuthentication.generateCodeVerifier()
        let challenge = BlueskyAuthentication.codeChallenge(for: verifier)

        // Base64URL uses only A-Z, a-z, 0-9, -, _  (no +, /, or =)
        XCTAssertFalse(challenge.contains("+"))
        XCTAssertFalse(challenge.contains("/"))
        XCTAssertFalse(challenge.contains("="))
        XCTAssertFalse(challenge.isEmpty)
    }

    func testCodeVerifierIsURLSafe() {
        let verifier = BlueskyAuthentication.generateCodeVerifier()

        XCTAssertFalse(verifier.isEmpty)
        XCTAssertFalse(verifier.contains("+"))
        XCTAssertFalse(verifier.contains("/"))
        XCTAssertFalse(verifier.contains("="))
    }

    func testAuthorizationURLBuildsCorrectly() {
        let endpoint = URL(string: "https://bsky.social/oauth/authorize")!
        let url = BlueskyAuthentication.authorizationURL(
            authorizationEndpoint: endpoint,
            clientId: "https://myapp.example.com/client-metadata.json",
            redirectUri: "myapp://callback",
            codeChallenge: "abc123challenge",
            loginHint: "user.bsky.social",
            state: "random-state"
        )

        XCTAssertNotNil(url)
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let queryDict = Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )

        XCTAssertEqual(queryDict["response_type"], "code")
        XCTAssertEqual(queryDict["code_challenge_method"], "S256")
        XCTAssertEqual(queryDict["code_challenge"], "abc123challenge")
        XCTAssertEqual(queryDict["login_hint"], "user.bsky.social")
        XCTAssertEqual(queryDict["state"], "random-state")
    }
}

@testable import APWebAuthentication
import CryptoKit
import Foundation
import XCTest

final class DPoPKeyTests: XCTestCase {

    func testPublicJWK_isP256WithCoordinates() {
        let key = DPoPKey()
        let jwk = key.publicJWK

        XCTAssertEqual(jwk["kty"], "EC")
        XCTAssertEqual(jwk["crv"], "P-256")
        XCTAssertEqual(base64URLDecode(jwk["x"] ?? "")?.count, 32)
        XCTAssertEqual(base64URLDecode(jwk["y"] ?? "")?.count, 32)
    }

    func testRawRepresentation_roundTripsToSameKey() throws {
        let key = DPoPKey()
        let restored = try DPoPKey(rawRepresentation: key.rawRepresentation)

        XCTAssertEqual(restored.publicJWK, key.publicJWK)
        XCTAssertEqual(restored.thumbprint, key.thumbprint)
    }

    func testProof_hasExpectedHeaderAndClaims() throws {
        let key = DPoPKey()
        let url = URL(string: "https://pds.example.com/xrpc/app.bsky.actor.getProfile?actor=did:plc:abc#frag")!
        let issuedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let proof = try key.proof(method: "get", url: url, nonce: "nonce-1", accessToken: "token-1", issuedAt: issuedAt)
        let parts = proof.split(separator: ".").map(String.init)
        XCTAssertEqual(parts.count, 3)

        let header = try json(parts[0])
        XCTAssertEqual(header["typ"] as? String, "dpop+jwt")
        XCTAssertEqual(header["alg"] as? String, "ES256")
        XCTAssertEqual(header["jwk"] as? [String: String], key.publicJWK)

        let claims = try json(parts[1])
        XCTAssertEqual(claims["htm"] as? String, "GET")
        XCTAssertEqual(claims["htu"] as? String, "https://pds.example.com/xrpc/app.bsky.actor.getProfile")
        XCTAssertEqual(claims["iat"] as? Int, 1_700_000_000)
        XCTAssertEqual(claims["exp"] as? Int, 1_700_000_030, "expires 30s after issue by default")
        XCTAssertEqual(claims["nonce"] as? String, "nonce-1")
        XCTAssertNotNil(claims["jti"] as? String)

        let expectedATH = Data(SHA256.hash(data: Data("token-1".utf8))).base64URLEncodedString()
        XCTAssertEqual(claims["ath"] as? String, expectedATH)
    }

    func testProof_omitsNonceAndATHWhenAbsent() throws {
        let key = DPoPKey()
        let proof = try key.proof(method: "POST", url: URL(string: "https://bsky.social/oauth/par")!)
        let claims = try json(proof.split(separator: ".").map(String.init)[1])

        XCTAssertNil(claims["nonce"])
        XCTAssertNil(claims["ath"])
    }

    func testProof_signatureVerifiesWithPublicJWK() throws {
        let key = DPoPKey()
        let proof = try key.proof(method: "POST", url: URL(string: "https://bsky.social/oauth/token")!)
        let parts = proof.split(separator: ".").map(String.init)

        let jwk = key.publicJWK
        let raw = try XCTUnwrap(base64URLDecode(jwk["x"]!)) + (try XCTUnwrap(base64URLDecode(jwk["y"]!)))
        let publicKey = try P256.Signing.PublicKey(rawRepresentation: raw)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: try XCTUnwrap(base64URLDecode(parts[2])))

        XCTAssertTrue(publicKey.isValidSignature(signature, for: Data("\(parts[0]).\(parts[1])".utf8)))
    }

    func testProof_honoursCustomLifetime() throws {
        let key = DPoPKey()
        let issuedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let proof = try key.proof(method: "POST", url: URL(string: "https://pds.example.com/xrpc/x")!, issuedAt: issuedAt, validFor: 10)
        let claims = try json(proof.split(separator: ".").map(String.init)[1])

        XCTAssertEqual(claims["exp"] as? Int, 1_700_000_010)
    }

    func testProof_jtiIsUniquePerProof() throws {
        let key = DPoPKey()
        let url = URL(string: "https://bsky.social/oauth/token")!
        let first = try json(try key.proof(method: "POST", url: url).split(separator: ".").map(String.init)[1])
        let second = try json(try key.proof(method: "POST", url: url).split(separator: ".").map(String.init)[1])

        XCTAssertNotEqual(first["jti"] as? String, second["jti"] as? String)
    }

    // MARK: - Helpers

    private func json(_ segment: String) throws -> [String: Any] {
        let data = try XCTUnwrap(base64URLDecode(segment))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

func base64URLDecode(_ string: String) -> Data? {
    var base64 = string
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    while base64.count % 4 != 0 {
        base64 += "="
    }
    return Data(base64Encoded: base64)
}

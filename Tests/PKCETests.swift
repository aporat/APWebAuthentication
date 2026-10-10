@testable import APWebAuthentication
import XCTest

final class PKCETests: XCTestCase {

    /// RFC 7636 Appendix B.
    private let rfcVerifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    private let rfcChallenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

    func testRFC7636AppendixB_octetsEncodeToVerifier() {
        let octets: [UInt8] = [
            116, 24, 223, 180, 151, 153, 224, 37, 79, 250, 96, 125, 216, 173,
            187, 186, 22, 212, 37, 77, 105, 214, 191, 240, 91, 88, 5, 88, 83,
            132, 141, 121
        ]
        XCTAssertEqual(Data(octets).base64URLEncodedString(), rfcVerifier)
    }

    func testRFC7636AppendixB_challenge() throws {
        XCTAssertEqual(PKCE.challenge(for: rfcVerifier), rfcChallenge)

        let pkce = try PKCE(verifier: rfcVerifier)
        XCTAssertEqual(pkce.verifier, rfcVerifier)
        XCTAssertEqual(pkce.challenge, rfcChallenge)
        XCTAssertEqual(PKCE.method, "S256")
    }

    func testATProtoUsesSharedImplementation() {
        XCTAssertEqual(ATProtoOAuthClient.codeChallenge(for: rfcVerifier), rfcChallenge)
        XCTAssertTrue(PKCE.isValidVerifier(ATProtoOAuthClient.randomToken()))
    }

    func testRandomPair_isValidAndUnique() {
        let first = PKCE()
        let second = PKCE()

        XCTAssertEqual(first.verifier.count, 43)
        XCTAssertTrue(PKCE.isValidVerifier(first.verifier))
        XCTAssertEqual(first.challenge, PKCE.challenge(for: first.verifier))
        XCTAssertNotEqual(first.verifier, second.verifier)
    }

    func testVerifierValidation() {
        XCTAssertTrue(PKCE.isValidVerifier(String(repeating: "a", count: 43)))
        XCTAssertTrue(PKCE.isValidVerifier(String(repeating: "A", count: 128)))
        XCTAssertTrue(PKCE.isValidVerifier(String(repeating: "-._~", count: 11)))

        XCTAssertFalse(PKCE.isValidVerifier(String(repeating: "a", count: 42)))
        XCTAssertFalse(PKCE.isValidVerifier(String(repeating: "a", count: 129)))
        XCTAssertFalse(PKCE.isValidVerifier(String(repeating: "a", count: 42) + "+"))
        XCTAssertFalse(PKCE.isValidVerifier(String(repeating: "a", count: 42) + "é"))

        XCTAssertThrowsError(try PKCE(verifier: "short"))
    }
}

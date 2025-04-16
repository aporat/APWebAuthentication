import XCTest
import Alamofire
import CryptoKit
@testable import APWebAuthentication

final class AuthClientTests: XCTestCase {

    var client: AuthClient!

    override func setUp() {
        super.setUp()
        client = AuthClient(baseURLString: "https://example.com")
        client.sessionManager = Session.default
    }

    func testInit_setsBaseURL() {
        XCTAssertEqual(client.baseURLString, "https://example.com")
    }

    func testFlags_propagateToRetrier() {
        client.isReloadingCancelled = true
        XCTAssertTrue(client.requestRetrier.isReloadingCancelled)

        client.shouldRetryRateLimit = true
        XCTAssertTrue(client.requestRetrier.shouldRetryRateLimit)

        client.shouldAlwaysShowLoginAgain = true
        XCTAssertTrue(client.requestRetrier.shouldAlwaysShowLoginAgain)
    }

    func testDecryptToken_success() {
        let password = "supersecret"
        let message = "hello world"
        let messageData = message.data(using: .utf8)!
        let key = SymmetricKey(data: SHA256.hash(data: Data(password.utf8)))
        let sealedBox = try! AES.GCM.seal(messageData, using: key)

        let payload = sealedBox.ciphertext.base64EncodedString()
        let tag = sealedBox.tag.base64EncodedString()
        let iv = Data(sealedBox.nonce).base64EncodedString()

        let decrypted = client.decryptToken(payload, tag: tag, iv: iv, password: password)
        XCTAssertEqual(decrypted, message)
    }

    func testDecryptToken_invalidInput_returnsNil() {
        XCTAssertNil(client.decryptToken("bad", tag: "data", iv: "here", password: "wrong"))
    }
}

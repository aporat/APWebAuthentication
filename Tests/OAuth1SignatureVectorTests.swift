@testable import APWebAuthentication
import XCTest

/// OAuth 1.0a signing checked against published test vectors.
@MainActor
final class OAuth1SignatureVectorTests: XCTestCase {

    // MARK: - RFC 5849 §3.4.1.1 (signature base string)

    /// The RFC's own example. It publishes the base string but not the
    /// secrets behind its signature, so only the base string is checked —
    /// end-to-end through the same query and body parsing the interceptor uses.
    func testRFC5849_section3_4_1_1_baseString() throws {
        let url = try XCTUnwrap(URL(string: "http://example.com/request?b5=%3D%253D&a3=a&c%40=&a2=r%20b"))
        var parameters: [(String, String)] = [
            ("oauth_consumer_key", "9djdj82h48djs9d2"),
            ("oauth_token", "kkk9d7dh3k39sjv7"),
            ("oauth_signature_method", "HMAC-SHA1"),
            ("oauth_timestamp", "137131201"),
            ("oauth_nonce", "7d8f3e4a")
        ]
        parameters += url.queryParameterItems
        parameters += URL.parseFormURLEncoded("c2&a3=2+q")

        let base = try OAuth1Interceptor.signatureBaseString(method: "POST", url: url, parameters: parameters)

        XCTAssertEqual(
            base,
            "POST&http%3A%2F%2Fexample.com%2Frequest&a2%3Dr%2520b%26a3%3D2%2520q"
                + "%26a3%3Da%26b5%3D%253D%25253D%26c%2540%3D%26c2%3D%26oauth_consumer_"
                + "key%3D9djdj82h48djs9d2%26oauth_nonce%3D7d8f3e4a%26oauth_signature_m"
                + "ethod%3DHMAC-SHA1%26oauth_timestamp%3D137131201%26oauth_token%3Dkkk"
                + "9d7dh3k39sjv7"
        )
    }

    // MARK: - RFC 5849 §1.2 (photos.example.net)

    func testRFC5849_section1_2_signature() throws {
        let url = try XCTUnwrap(URL(string: "http://photos.example.net/photos?file=vacation.jpg&size=original"))
        var parameters: [(String, String)] = [
            ("oauth_consumer_key", "dpf43f3p2l4k3l03"),
            ("oauth_token", "nnch734d00sl2jdk"),
            ("oauth_signature_method", "HMAC-SHA1"),
            ("oauth_timestamp", "137131202"),
            ("oauth_nonce", "chapoH")
        ]
        parameters += url.queryParameterItems

        let base = try OAuth1Interceptor.signatureBaseString(method: "GET", url: url, parameters: parameters)
        let signature = OAuth1Interceptor.hmacSHA1Signature(
            of: base,
            consumerSecret: "kd94hf93k423kf44",
            tokenSecret: "pfkkdhi9sl3r4s00"
        )

        // RFC: oauth_signature="MdpQcU8iPSUjWoN%2FUDMsK2sui9I%3D"
        XCTAssertEqual(signature, "MdpQcU8iPSUjWoN/UDMsK2sui9I=")
    }

    // MARK: - Twitter "Creating a signature" example

    private let twitterURL = URL(string: "https://api.twitter.com/1.1/statuses/update.json?include_entities=true")!
    private let twitterBody = "status=Hello%20Ladies%20%2b%20Gentlemen%2c%20a%20signed%20OAuth%20request%21"

    func testTwitterExample_baseStringAndSignature() throws {
        var parameters: [(String, String)] = [
            ("oauth_consumer_key", "xvz1evFS4wEEPTGEFPHBog"),
            ("oauth_nonce", "kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg"),
            ("oauth_signature_method", "HMAC-SHA1"),
            ("oauth_timestamp", "1318622958"),
            ("oauth_token", "370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb"),
            ("oauth_version", "1.0")
        ]
        parameters += twitterURL.queryParameterItems
        parameters += URL.parseFormURLEncoded(twitterBody)

        let base = try OAuth1Interceptor.signatureBaseString(method: "POST", url: twitterURL, parameters: parameters)

        XCTAssertEqual(
            base,
            "POST&https%3A%2F%2Fapi.twitter.com%2F1.1%2Fstatuses%2Fupdate.json&include_entities%3Dtrue"
                + "%26oauth_consumer_key%3Dxvz1evFS4wEEPTGEFPHBog%26oauth_nonce%3DkYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg"
                + "%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D1318622958"
                + "%26oauth_token%3D370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb%26oauth_version%3D1.0"
                + "%26status%3DHello%2520Ladies%2520%252B%2520Gentlemen%252C%2520a%2520signed%2520OAuth%2520request%2521"
        )
        XCTAssertEqual(
            OAuth1Interceptor.hmacSHA1Signature(
                of: base,
                consumerSecret: "kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw",
                tokenSecret: "LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE"
            ),
            "hCtSmYh+iHYCEqBWrE7C7hYmtUk="
        )
    }

    /// The same vector through the interceptor's full header builder, with
    /// the nonce and timestamp pinned.
    func testTwitterExample_authorizationHeader() throws {
        let interceptor = OAuth1Interceptor(auth: Auth1Authentication())

        let header = try interceptor.authorizationHeader(
            for: twitterURL,
            method: "POST",
            formParameters: URL.parseFormURLEncoded(twitterBody),
            consumerKey: "xvz1evFS4wEEPTGEFPHBog",
            consumerSecret: "kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw",
            authToken: "370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb",
            authSecret: "LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE",
            nonce: "kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg",
            timestamp: "1318622958"
        )

        XCTAssertEqual(
            header,
            "OAuth oauth_consumer_key=\"xvz1evFS4wEEPTGEFPHBog\", "
                + "oauth_nonce=\"kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg\", "
                + "oauth_signature=\"hCtSmYh%2BiHYCEqBWrE7C7hYmtUk%3D\", "
                + "oauth_signature_method=\"HMAC-SHA1\", "
                + "oauth_timestamp=\"1318622958\", "
                + "oauth_token=\"370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb\", "
                + "oauth_version=\"1.0\""
        )
    }

    func testRandomNonceAndTimestamp_whenNotPinned() {
        let interceptor = OAuth1Interceptor(auth: Auth1Authentication())
        let first = interceptor.buildOAuthParameters(consumerKey: "ck", token: nil)
        let second = interceptor.buildOAuthParameters(consumerKey: "ck", token: nil)

        XCTAssertNotEqual(first["oauth_nonce"], second["oauth_nonce"])
        XCTAssertNotNil(first["oauth_timestamp"].flatMap(Int.init))
        XCTAssertNil(first["oauth_token"])
    }
}

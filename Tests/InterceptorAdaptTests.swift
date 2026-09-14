import Alamofire
@testable import APWebAuthentication
import CryptoKit
import XCTest

/// Exercises what each interceptor's `adapt` actually emits — headers, query
/// string and body — without a network round trip.
@MainActor
final class InterceptorAdaptTests: XCTestCase {

    // MARK: - Helpers

    private func adapt(_ request: URLRequest, with interceptor: RequestInterceptor) async throws -> URLRequest {
        try await withCheckedThrowingContinuation { continuation in
            interceptor.adapt(request, for: Session.default) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func formRequest(_ method: HTTPMethod, url: String, body: String) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.method = method
        request.headers.add(.contentType("application/x-www-form-urlencoded; charset=utf-8"))
        request.httpBody = Data(body.utf8)
        return request
    }

    private func queryItems(of request: URLRequest) -> [String: String] {
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        return (components?.queryItems ?? []).reduce(into: [:]) { $0[$1.name] = $1.value }
    }

    private func body(of request: URLRequest) -> String? {
        request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - GitHub Content-Length

    func testGitHub_bodilessPUT_getsContentLengthZero() async throws {
        let auth = Auth2Authentication()
        auth.accessToken = "token"
        var request = URLRequest(url: URL(string: "https://api.github.com/user/starred/owner/repo")!)
        request.method = .put

        let adapted = try await adapt(request, with: GitHubInterceptor(auth: auth))

        XCTAssertEqual(adapted.headers["Content-Length"], "0")
        XCTAssertEqual(adapted.headers["Authorization"], "Bearer token")
    }

    func testGitHub_PUTWithBody_keepsBodyAndNoForcedContentLength() async throws {
        let auth = Auth2Authentication()
        auth.accessToken = "token"
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/o/r/contents/f")!)
        request.method = .put
        request.headers.add(.contentType("application/json"))
        request.httpBody = Data(#"{"message":"m","content":"YQ=="}"#.utf8)

        let adapted = try await adapt(request, with: GitHubInterceptor(auth: auth))

        XCTAssertNil(adapted.headers["Content-Length"])
        XCTAssertEqual(body(of: adapted), #"{"message":"m","content":"YQ=="}"#)
    }

    // MARK: - OAuth2 token in query string

    func testOAuth2Params_POST_keepsBodyAndPutsTokenInQuery() async throws {
        let auth = Auth2Authentication()
        auth.accessToken = "abc"
        let interceptor = OAuth2Interceptor(auth: auth, tokenLocation: .params, tokenParamName: "oauth_token")
        let request = formRequest(.post, url: "https://api.example.com/checkins/add", body: "venueId=42&shout=hi")

        let adapted = try await adapt(request, with: interceptor)

        XCTAssertEqual(body(of: adapted), "venueId=42&shout=hi")
        XCTAssertEqual(queryItems(of: adapted)["oauth_token"], "abc")
    }

    func testOAuth2Params_GET_putsTokenInQuery() async throws {
        let auth = Auth2Authentication()
        auth.accessToken = "abc"
        let interceptor = OAuth2Interceptor(auth: auth, tokenLocation: .params)
        let request = URLRequest(url: URL(string: "https://api.example.com/me?fields=id")!)

        let adapted = try await adapt(request, with: interceptor)

        XCTAssertEqual(queryItems(of: adapted), ["fields": "id", "access_token": "abc"])
        XCTAssertNil(adapted.httpBody)
    }

    func testFoursquare_POST_keepsBodyAndAddsVersionAndTokenToQuery() async throws {
        let auth = Auth2Authentication()
        auth.accessToken = "fsq"
        let request = formRequest(.post, url: "https://api.foursquare.com/v2/checkins/add", body: "venueId=42")

        let adapted = try await adapt(request, with: FoursquareInterceptor(auth: auth))

        XCTAssertEqual(body(of: adapted), "venueId=42")
        let query = queryItems(of: adapted)
        XCTAssertEqual(query["v"], "20240109")
        XCTAssertEqual(query["oauth_token"], "fsq")
    }

    // MARK: - OAuth1 body signing

    func testOAuth1_contentTypeClassification() {
        XCTAssertTrue(OAuth1Interceptor.isFormURLEncoded("application/x-www-form-urlencoded"))
        XCTAssertTrue(OAuth1Interceptor.isFormURLEncoded("Application/X-WWW-Form-URLEncoded; charset=utf-8"))
        XCTAssertFalse(OAuth1Interceptor.isFormURLEncoded("application/json"))
        XCTAssertFalse(OAuth1Interceptor.isFormURLEncoded("multipart/form-data; boundary=x"))
        XCTAssertFalse(OAuth1Interceptor.isFormURLEncoded(nil))
    }

    func testOAuth1_PUTFormBody_isIncludedInSignature() async throws {
        let auth = makeOAuth1Auth()
        let request = formRequest(.put, url: "https://api.example.com/v1/thing?x=1", body: "status=hello+world&scope=a&scope=b")

        let adapted = try await adapt(request, with: OAuth1Interceptor(auth: auth))

        let expected = expectedSignature(
            for: adapted,
            method: "PUT",
            baseURL: "https://api.example.com/v1/thing",
            extraParameters: [("x", "1"), ("status", "hello world"), ("scope", "a"), ("scope", "b")]
        )
        XCTAssertEqual(oauthHeaderParameters(of: adapted)["oauth_signature"], expected)
    }

    func testOAuth1_JSONBody_isNotIncludedInSignature() async throws {
        let auth = makeOAuth1Auth()
        var request = URLRequest(url: URL(string: "https://api.example.com/2/tweets")!)
        request.method = .post
        request.headers.add(.contentType("application/json"))
        request.httpBody = Data(#"{"text":"a=b&c=d"}"#.utf8)

        let adapted = try await adapt(request, with: OAuth1Interceptor(auth: auth))

        let expected = expectedSignature(
            for: adapted,
            method: "POST",
            baseURL: "https://api.example.com/2/tweets",
            extraParameters: []
        )
        XCTAssertEqual(oauthHeaderParameters(of: adapted)["oauth_signature"], expected)
        XCTAssertEqual(body(of: adapted), #"{"text":"a=b&c=d"}"#)
    }

    // MARK: - OAuth1 test support

    private func makeOAuth1Auth() -> Auth1Authentication {
        let auth = Auth1Authentication()
        auth.consumerKey = "ck"
        auth.consumerSecret = "cs"
        auth.token = "tk"
        auth.secret = "ts"
        return auth
    }

    /// Parses `OAuth k="v", k2="v2"` into its (percent-decoded) parameters.
    private func oauthHeaderParameters(of request: URLRequest) -> [String: String] {
        guard let header = request.headers["Authorization"], header.hasPrefix("OAuth ") else { return [:] }
        return header.dropFirst("OAuth ".count)
            .components(separatedBy: ", ")
            .reduce(into: [:]) { result, pair in
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return }
                result[parts[0].urlUnescaped] = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"")).urlUnescaped
            }
    }

    /// Recomputes the RFC 5849 signature from the nonce/timestamp the
    /// interceptor chose plus the parameters we expect it to have signed.
    private func expectedSignature(
        for request: URLRequest,
        method: String,
        baseURL: String,
        extraParameters: [(String, String)]
    ) -> String {
        let header = oauthHeaderParameters(of: request)
        var pairs: [(String, String)] = header
            .filter { $0.key != "oauth_signature" }
            .map { ($0.key, $0.value) }
        pairs.append(contentsOf: extraParameters)

        let encoded: [(String, String)] = pairs.map { pair in
            (pair.0.urlEscaped, pair.1.urlEscaped)
        }
        let sorted: [(String, String)] = encoded.sorted { lhs, rhs in
            lhs.0 == rhs.0 ? lhs.1 < rhs.1 : lhs.0 < rhs.0
        }
        let joined: [String] = sorted.map { pair in "\(pair.0)=\(pair.1)" }
        let parameterString = joined.joined(separator: "&")

        let base = "\(method)&\(baseURL.urlEscaped)&\(parameterString.urlEscaped)"
        let key = SymmetricKey(data: Data("cs&ts".utf8))
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: Data(base.utf8), using: key)
        return Data(mac).base64EncodedString()
    }
}

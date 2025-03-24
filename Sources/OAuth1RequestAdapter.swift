import Alamofire
import CryptoSwift
import SwifterSwift
import Foundation

open class OAuth1RequestAdapter: RequestAdapter {
    var dataEncoding: String.Encoding = .utf8
    var auth: Auth1Authentication
    var consumerKey: String
    var consumerSecret: String

    public init(consumerKey: String, consumerSecret: String, auth: Auth1Authentication) {
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.auth = auth
    }

    public func adapt(_ urlRequest: URLRequest, for _: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest

        var formParameters: [String: String] = [:]
        if urlRequest.method == .post {
            formParameters = urlRequest.httpBody!.string(encoding: .utf8)!.parameters
            urlRequest.httpBody = httpBody(forFormParameters: formParameters)
        }

        let authHeader = authorizationHeader(url: urlRequest.url!, method: urlRequest.httpMethod!, parameter: formParameters)

        urlRequest.headers.add(.authorization(authHeader))

        if let currentUserAgent = auth.userAgent, !currentUserAgent.isEmpty {
            urlRequest.headers.add(.userAgent(currentUserAgent))
        }

        urlRequest.headers.add(.accept("application/json"))

        completion(.success(urlRequest))
        return
    }

    /// Function to calculate the OAuth protocol parameters and signature ready to be added
    /// as the HTTP header "Authorization" entry. A detailed explanation of the procedure
    /// can be found at: [RFC-5849 Section 3](https://tools.ietf.org/html/rfc5849#section-3)
    ///
    /// - Parameters:
    ///   - url: Request url (with all query parameters etc.)
    ///   - method: HTTP method
    ///   - parameter: url-form parameters
    ///   - consumerCredentials: consumer credentials
    ///   - userCredentials: user credentials (nil if this is a request without user association)
    ///
    /// - Returns: OAuth HTTP header entry for the Authorization field.
    private func authorizationHeader(url: URL, method: String, parameter: [String: String]) -> String {
        typealias Tup = (key: String, value: String)

        let tuplify: (String, String) -> Tup = {
            (key: $0.urlEscaped, value: $1.urlEscaped)
        }
        let cmp: (Tup, Tup) -> Bool = {
            $0.key < $1.key
        }
        let toPairString: (Tup) -> String = {
            $0.key + "=" + $0.value
        }
        let toBrackyPairString: (Tup) -> String = {
            $0.key + "=\"" + $0.value + "\""
        }

        /// [RFC-5849 Section 3.1](https://tools.ietf.org/html/rfc5849#section-3.1)
        var oAuthParameters = authorizationParameters(consumerKey: consumerKey, token: auth.token)

        /// [RFC-5849 Section 3.4.1.3.1](https://tools.ietf.org/html/rfc5849#section-3.4.1.3.1)
        let signString: String = [oAuthParameters, parameter, url.parameters]
            .flatMap { $0.map(tuplify) }
            .sorted(by: cmp)
            .map(toPairString)
            .joined(separator: "&")

        /// [RFC-5849 Section 3.4.1](https://tools.ietf.org/html/rfc5849#section-3.4.1)
        let signatureBase: String = [method.urlEscaped, url.oAuthBaseURL.urlEscaped, signString.urlEscaped]
            .joined(separator: "&")

        /// [RFC-5849 Section 3.4.2](https://tools.ietf.org/html/rfc5849#section-3.4.2)
        let signingKey: String = [consumerSecret, auth.secret ?? ""].joined(separator: "&")

        /// [RFC-5849 Section 3.4.2](https://tools.ietf.org/html/rfc5849#section-3.4.2)
        let bytes: [UInt8] = Array(signatureBase.utf8)

        if let signature = try? HMAC(key: signingKey, variant: .sha1).authenticate(bytes) {
            oAuthParameters["oauth_signature"] = signature.toBase64()
        }

        /// [RFC-5849 Section 3.5.1](https://tools.ietf.org/html/rfc5849#section-3.5.1)
        return "OAuth " + oAuthParameters
            .map(tuplify)
            .sorted(by: cmp)
            .map(toBrackyPairString)
            .joined(separator: ",")
    }

    private func httpBody(forFormParameters paras: [String: String], encoding: String.Encoding = .utf8) -> Data? {
        let trans: (String, String) -> String = { k, v in
            k.urlEscaped + "=" + v.urlEscaped
        }

        return paras.map(trans).joined(separator: "&").data(using: encoding)
    }

    private func authorizationParameters(consumerKey: String, token: String?) -> [String: String] {
        /// [RFC-5849 Section 3.1](https://tools.ietf.org/html/rfc5849#section-3.1)
        var defaults: [String: String] = [
            "oauth_consumer_key": consumerKey,
            "oauth_signature_method": "HMAC-SHA1",
            "oauth_version": "1.0",
            /// [RFC-5849 Section 3.3](https://tools.ietf.org/html/rfc5849#section-3.3)
            "oauth_timestamp": String(Int(Date().timeIntervalSince1970)),
            "oauth_nonce": UUID().uuidString,
        ]
        if let token = token {
            defaults["oauth_token"] = token
        }
        return defaults
    }
}

import CryptoKit
import Foundation

/// An ES256 (P-256) key pair that signs DPoP proofs (RFC 9449).
///
/// AT Protocol OAuth binds every access token to a client-held key: each
/// request to the authorization server or the user's PDS carries a short
/// lived JWT signed with this key, and the server rejects tokens presented
/// without a matching proof. The key never leaves the device; it is stored
/// alongside the tokens in the Keychain via ``ATProtoAuthentication``.
///
/// **Example:**
/// ```swift
/// let key = DPoPKey()
/// let proof = try key.proof(method: "POST", url: tokenURL, nonce: nonce)
/// request.headers.add(name: "DPoP", value: proof)
/// ```
public struct DPoPKey: @unchecked Sendable {

    private let privateKey: P256.Signing.PrivateKey

    /// Matches the reference implementations: long enough to survive a slow
    /// network, far shorter than the server's own nonce rotation.
    public static let defaultProofLifetime: TimeInterval = 30

    // MARK: - Initialization

    /// Generates a fresh key pair. A new key is minted for every login.
    public init() {
        privateKey = P256.Signing.PrivateKey()
    }

    /// Restores a key from its `rawRepresentation` (the 32-byte scalar).
    public init(rawRepresentation: Data) throws {
        privateKey = try P256.Signing.PrivateKey(rawRepresentation: rawRepresentation)
    }

    /// The private scalar, for persistence. Treat as a secret.
    public var rawRepresentation: Data {
        privateKey.rawRepresentation
    }

    // MARK: - Public Key

    /// The public key as a JSON Web Key (RFC 7517), the shape the `jwk`
    /// header of every proof carries.
    public var publicJWK: [String: String] {
        let raw = privateKey.publicKey.rawRepresentation // X || Y, 32 bytes each
        return [
            "kty": "EC",
            "crv": "P-256",
            "x": raw.prefix(32).base64URLEncodedString(),
            "y": raw.suffix(32).base64URLEncodedString()
        ]
    }

    /// RFC 7638 thumbprint of the public key, which is what a server records
    /// as the token's `cnf.jkt` binding.
    public var thumbprint: String {
        let jwk = publicJWK
        // Members are hashed in lexicographic order with no whitespace.
        let canonical = "{\"crv\":\"\(jwk["crv"]!)\",\"kty\":\"\(jwk["kty"]!)\",\"x\":\"\(jwk["x"]!)\",\"y\":\"\(jwk["y"]!)\"}"
        return Data(SHA256.hash(data: Data(canonical.utf8))).base64URLEncodedString()
    }

    // MARK: - Proofs

    /// Builds a signed DPoP proof for one HTTP request.
    ///
    /// - Parameters:
    ///   - method: The HTTP method, upper-cased (`htm`).
    ///   - url: The request URL; query and fragment are dropped (`htu`).
    ///   - nonce: The most recent `DPoP-Nonce` the server handed out, if any.
    ///   - accessToken: For resource requests, the token being presented;
    ///     its SHA-256 hash is bound into the proof (`ath`).
    ///   - issuedAt: Overridable for tests.
    ///   - validFor: Lifetime of the proof (`exp`). Proofs are single use and
    ///     sent immediately, so a short window limits replay if one leaks.
    public func proof(
        method: String,
        url: URL,
        nonce: String? = nil,
        accessToken: String? = nil,
        issuedAt: Date = Date(),
        validFor: TimeInterval = DPoPKey.defaultProofLifetime
    ) throws -> String {
        let header: [String: Any] = [
            "typ": "dpop+jwt",
            "alg": "ES256",
            "jwk": publicJWK
        ]

        var claims: [String: Any] = [
            "jti": UUID().uuidString,
            "htm": method.uppercased(),
            "htu": Self.htu(for: url),
            "iat": Int(issuedAt.timeIntervalSince1970),
            "exp": Int(issuedAt.addingTimeInterval(validFor).timeIntervalSince1970)
        ]
        if let nonce, !nonce.isEmpty {
            claims["nonce"] = nonce
        }
        if let accessToken, !accessToken.isEmpty {
            claims["ath"] = Data(SHA256.hash(data: Data(accessToken.utf8))).base64URLEncodedString()
        }

        let encodedHeader = try Self.encode(header)
        let encodedClaims = try Self.encode(claims)
        let signingInput = "\(encodedHeader).\(encodedClaims)"

        // JWS ES256 wants the raw `r || s` pair, not the DER encoding.
        let signature = try privateKey.signature(for: Data(signingInput.utf8)).rawRepresentation
        return "\(signingInput).\(signature.base64URLEncodedString())"
    }

    /// The `htu` claim: scheme, host, port and path only (RFC 9449 §4.2).
    static func htu(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.query = nil
        components.fragment = nil
        return components.string ?? url.absoluteString
    }

    private static func encode(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        return data.base64URLEncodedString()
    }
}

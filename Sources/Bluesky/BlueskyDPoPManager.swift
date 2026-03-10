import CryptoKit
import Foundation

// MARK: - BlueskyDPoPManager

/// Generates DPoP (Demonstrating Proof-of-Possession) proof JWTs for AT Protocol OAuth.
///
/// DPoP binds an access token to a specific ES256 key pair held by the client, preventing
/// token theft. A unique DPoP proof JWT must be sent with every token request and every
/// authorized API call.
///
/// **DPoP JWT Structure:**
///
/// *Header:*
/// ```json
/// { "typ": "dpop+jwt", "alg": "ES256", "jwk": { "kty": "EC", "crv": "P-256", "x": "...", "y": "..." } }
/// ```
///
/// *Payload:*
/// ```json
/// { "jti": "<uuid>", "htm": "GET", "htu": "https://bsky.social/xrpc/...", "iat": 1700000000 }
/// ```
///
/// - Note: Each proof JWT is single-use (`jti` is a random UUID) and must not be reused.
///
/// **References:**
/// - [AT Protocol OAuth](https://atproto.com/specs/oauth)
/// - [RFC 9449 – DPoP](https://www.rfc-editor.org/rfc/rfc9449)
public enum BlueskyDPoPManager {

    // MARK: - Proof Generation

    /// Creates a signed DPoP proof JWT for the given HTTP request context.
    ///
    /// - Parameters:
    ///   - privateKey: The ES256 private key for this session.
    ///   - method: The HTTP method (e.g. `"GET"`, `"POST"`).
    ///   - url: The target URL — query parameters and fragments are stripped per RFC 9449.
    ///   - accessToken: The bound access token. When present, its SHA-256 hash is
    ///     included as the `ath` claim.
    ///   - nonce: A server-issued nonce from a previous `DPoP-Nonce` response header.
    /// - Throws: `BlueskyDPoPError` if JSON serialization or signing fails.
    /// - Returns: The compact serialization of the DPoP proof JWT.
    public static func makeProof(
        privateKey: P256.Signing.PrivateKey,
        method: String,
        url: URL,
        accessToken: String? = nil,
        nonce: String? = nil
    ) throws -> String {
        let publicKeyJWK = try publicKeyJWK(from: privateKey)

        // Header
        let header: [String: Any] = [
            "typ": "dpop+jwt",
            "alg": "ES256",
            "jwk": publicKeyJWK
        ]

        // Payload
        var payload: [String: Any] = [
            "jti": UUID().uuidString,
            "htm": method.uppercased(),
            "htu": htuValue(from: url),
            "iat": Int(Date().timeIntervalSince1970)
        ]

        if let nonce {
            payload["nonce"] = nonce
        }

        if let accessToken {
            let tokenHash = SHA256.hash(data: Data(accessToken.utf8))
            payload["ath"] = Data(tokenHash).base64URLEncodedString()
        }

        // Encode header and payload
        let headerData = try JSONSerialization.data(withJSONObject: header, options: .sortedKeys)
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: .sortedKeys)

        let headerEncoded = headerData.base64URLEncodedString()
        let payloadEncoded = payloadData.base64URLEncodedString()
        let signingInput = "\(headerEncoded).\(payloadEncoded)"

        // Sign with ES256 (P-256)
        let signature = try privateKey.signature(for: Data(signingInput.utf8))
        let signatureEncoded = signature.rawRepresentation.base64URLEncodedString()

        return "\(signingInput).\(signatureEncoded)"
    }

    // MARK: - JWK Helpers

    /// Converts the public half of a P-256 key pair into a JWK dictionary.
    ///
    /// The returned dictionary is suitable for embedding in DPoP JWT headers.
    ///
    /// - Parameter privateKey: The ES256 private key.
    /// - Returns: A JSON-compatible dictionary representing the EC public key.
    public static func publicKeyJWK(from privateKey: P256.Signing.PrivateKey) throws -> [String: String] {
        // rawRepresentation of PublicKey is 64 bytes: x (32) || y (32)
        let rawPublicKey = privateKey.publicKey.rawRepresentation
        guard rawPublicKey.count == 64 else {
            throw BlueskyDPoPError.invalidKeyFormat
        }
        let x = rawPublicKey.prefix(32)
        let y = rawPublicKey.suffix(32)

        return [
            "kty": "EC",
            "crv": "P-256",
            "x": Data(x).base64URLEncodedString(),
            "y": Data(y).base64URLEncodedString()
        ]
    }

    // MARK: - Private Helpers

    /// Returns the `htu` claim value: the URL without query string or fragment.
    private static func htuValue(from url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.url?.absoluteString ?? url.absoluteString
    }
}

// MARK: - BlueskyDPoPError

/// Errors thrown by `BlueskyDPoPManager`.
public enum BlueskyDPoPError: Error, LocalizedError {
    /// The public key raw representation has an unexpected length.
    case invalidKeyFormat
    /// JSON serialization of the JWT header or payload failed.
    case serializationFailed

    public var errorDescription: String? {
        switch self {
        case .invalidKeyFormat:
            return "DPoP key has an unexpected format (expected 64-byte P-256 raw representation)."
        case .serializationFailed:
            return "Failed to serialize DPoP JWT header or payload to JSON."
        }
    }
}

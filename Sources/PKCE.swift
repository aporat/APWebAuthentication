import CryptoKit
import Foundation

// MARK: - PKCE

/// A Proof Key for Code Exchange pair (RFC 7636) using the `S256` method.
///
/// Send ``challenge`` with ``method`` on the authorization request and
/// ``verifier`` on the token request. Only the client that started the login
/// knows the verifier, so an intercepted authorization code is useless on its
/// own.
///
/// ```swift
/// let pkce = PKCE()
/// // authorize: code_challenge=\(pkce.challenge)&code_challenge_method=S256
/// // token:     code_verifier=\(pkce.verifier)
/// ```
///
/// Only `S256` is offered. RFC 7636 §4.2 allows `plain` solely for clients
/// that cannot hash, and several providers (GitHub, Mastodon) reject it.
public struct PKCE: Sendable, Equatable {

    /// The `code_challenge_method` value for ``challenge``.
    public static let method = "S256"

    /// The high-entropy secret sent on the token request (`code_verifier`).
    public let verifier: String

    /// `BASE64URL(SHA256(ASCII(verifier)))`, sent on the authorization request
    /// (`code_challenge`).
    public let challenge: String

    /// A fresh pair with a random 43-character verifier (32 random bytes).
    public init() {
        let verifier = Self.generateVerifier()
        self.verifier = verifier
        self.challenge = Self.challenge(for: verifier)
    }

    /// A pair for a verifier you already have, e.g. one restored after the
    /// app was relaunched mid-login.
    ///
    /// - Throws: `.failed` unless the verifier is 43–128 characters from the
    ///   unreserved set `[A-Z] / [a-z] / [0-9] / "-" / "." / "_" / "~"`
    ///   (RFC 7636 §4.1).
    public init(verifier: String) throws(APWebAuthenticationError) {
        guard Self.isValidVerifier(verifier) else {
            throw .failed(reason: "Invalid PKCE code verifier.")
        }
        self.verifier = verifier
        self.challenge = Self.challenge(for: verifier)
    }

    // MARK: - Primitives

    /// 32 random bytes, base64url without padding: 43 characters, ~256 bits
    /// of entropy. Also suitable as an OAuth `state` value.
    public static func generateVerifier() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64URLEncodedString()
    }

    /// The `S256` challenge for `verifier` (RFC 7636 §4.2).
    public static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }

    /// Whether `verifier` satisfies RFC 7636 §4.1.
    public static func isValidVerifier(_ verifier: String) -> Bool {
        guard (43...128).contains(verifier.count) else { return false }
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return verifier.unicodeScalars.allSatisfy { unreserved.contains($0) }
    }
}

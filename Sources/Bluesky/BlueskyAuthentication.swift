import CryptoKit
import Foundation
@preconcurrency import SwiftyJSON

// MARK: - BlueskyAuthentication

/// OAuth authentication manager for the Bluesky / AT Protocol.
///
/// Extends `Auth2Authentication` with AT Protocol-specific fields:
/// - Account DID (Decentralized Identifier)
/// - AT Protocol handle (e.g. `user.bsky.social`)
/// - DPoP (Demonstrating Proof-of-Possession) key pair for token binding
///
/// **AT Protocol OAuth Flow:**
/// 1. Resolve the handle to a DID and locate the Authorization Server
/// 2. Generate a PKCE code verifier/challenge and a DPoP key pair
/// 3. Optionally perform a Pushed Authorization Request (PAR)
/// 4. Open the authorization URL in a web view
/// 5. Exchange the authorization code for tokens (with DPoP)
/// 6. Use the access token + DPoP on every API request
///
/// **Example Usage:**
/// ```swift
/// let auth = BlueskyAuthentication()
/// auth.handle = "user.bsky.social"
/// auth.clientId = "https://myapp.example.com/client-metadata.json"
/// auth.accessToken = "<access_token>"
/// auth.refreshToken = "<refresh_token>"
/// auth.did = "did:plc:abc123"
///
/// if auth.isAuthorized {
///     await auth.save()
/// }
/// ```
@MainActor
public final class BlueskyAuthentication: Auth2Authentication {

    // MARK: - Settings Storage

    private struct BlueskyAuthSettings: Codable, Sendable {
        let accessToken: String?
        let refreshToken: String?
        let clientId: String?
        let did: String?
        let handle: String?
        let dpopPrivateKeyData: Data?
    }

    // MARK: - AT Protocol Properties

    /// The account's Decentralized Identifier (DID), e.g. `did:plc:abc123`.
    ///
    /// This is returned as the `sub` claim in the token response and must be
    /// verified to match the expected account after token exchange.
    public var did: String?

    /// The AT Protocol handle, e.g. `user.bsky.social`.
    public var handle: String?

    /// Raw representation of the ES256 (P-256) DPoP private key.
    ///
    /// - Note: A new key pair is generated automatically on first access via
    ///   `dpopPrivateKey`. The raw data is persisted so that an in-progress
    ///   session can survive app restarts.
    public var dpopPrivateKeyData: Data?

    // MARK: - Computed DPoP Properties

    /// The ES256 private key used to sign DPoP proof JWTs.
    ///
    /// If `dpopPrivateKeyData` is set, that key is reconstructed; otherwise a new
    /// key is generated and stored in `dpopPrivateKeyData`.
    public var dpopPrivateKey: P256.Signing.PrivateKey {
        if let data = dpopPrivateKeyData,
           let key = try? P256.Signing.PrivateKey(rawRepresentation: data) {
            return key
        }
        let newKey = P256.Signing.PrivateKey()
        dpopPrivateKeyData = newKey.rawRepresentation
        return newKey
    }

    /// Rotates the DPoP key pair, generating a fresh ES256 private key.
    ///
    /// Call this at the start of each new OAuth session to comply with the
    /// AT Protocol requirement that DPoP keys are never reused across sessions.
    public func rotateDPoPKey() {
        let newKey = P256.Signing.PrivateKey()
        dpopPrivateKeyData = newKey.rawRepresentation
    }

    // MARK: - PKCE Helpers

    /// Generates a cryptographically random PKCE code verifier (RFC 7636).
    ///
    /// - Returns: A URL-safe base64 string of 32 random bytes.
    public static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    /// Derives the PKCE S256 code challenge from a verifier.
    ///
    /// - Parameter verifier: The code verifier produced by `generateCodeVerifier()`.
    /// - Returns: Base64url-encoded SHA-256 hash of the verifier.
    public static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let digest = SHA256.hash(data: data)
        return Data(digest).base64URLEncodedString()
    }

    // MARK: - Authorization URL Construction

    /// Builds the Bluesky authorization URL for the standard authorization code flow.
    ///
    /// - Parameters:
    ///   - authorizationEndpoint: The Authorization Server's authorization endpoint.
    ///   - clientId: Your OAuth client ID (must be a publicly reachable metadata URL for AT Protocol).
    ///   - redirectUri: Your app's redirect URI.
    ///   - codeChallenge: The PKCE S256 code challenge.
    ///   - loginHint: Optional pre-fill for the handle/DID field.
    ///   - scope: OAuth scopes to request (default: `"atproto transition:generic"`).
    ///   - state: Optional opaque state parameter for CSRF protection.
    ///   - requestUri: Optional PAR `request_uri` to use instead of inline parameters.
    /// - Returns: The authorization URL, or `nil` if the URL cannot be constructed.
    public static func authorizationURL(
        authorizationEndpoint: URL,
        clientId: String,
        redirectUri: String,
        codeChallenge: String,
        loginHint: String? = nil,
        scope: String = "atproto transition:generic",
        state: String? = nil,
        requestUri: String? = nil
    ) -> URL? {
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)

        if let requestUri {
            // PAR flow: only client_id and request_uri are needed.
            components?.queryItems = [
                URLQueryItem(name: "client_id", value: clientId),
                URLQueryItem(name: "request_uri", value: requestUri)
            ]
        } else {
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "client_id", value: clientId),
                URLQueryItem(name: "redirect_uri", value: redirectUri),
                URLQueryItem(name: "scope", value: scope),
                URLQueryItem(name: "code_challenge", value: codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256")
            ]
            if let loginHint {
                queryItems.append(URLQueryItem(name: "login_hint", value: loginHint))
            }
            if let state {
                queryItems.append(URLQueryItem(name: "state", value: state))
            }
            components?.queryItems = queryItems
        }

        return components?.url
    }

    // MARK: - Persistence

    /// Saves Bluesky credentials to disk.
    override public func save() async {
        let settings = BlueskyAuthSettings(
            accessToken: accessToken,
            refreshToken: refreshToken,
            clientId: clientId,
            did: did,
            handle: handle,
            dpopPrivateKeyData: dpopPrivateKeyData
        )

        guard let authSettingsURL else { return }

        do {
            let data = try PropertyListEncoder().encode(settings)
            try await Task.detached {
                try data.write(to: authSettingsURL)
            }.value
        } catch {
            print("⚠️ Failed to store Bluesky auth settings: \(error)")
        }
    }

    /// Loads Bluesky credentials from disk.
    override public func load() async {
        guard let authSettingsURL else { return }

        do {
            let data = try await Task.detached {
                try Data(contentsOf: authSettingsURL)
            }.value

            let settings = try PropertyListDecoder().decode(BlueskyAuthSettings.self, from: data)
            accessToken = settings.accessToken
            refreshToken = settings.refreshToken
            clientId = settings.clientId
            did = settings.did
            handle = settings.handle
            dpopPrivateKeyData = settings.dpopPrivateKeyData
        } catch {
            print("⚠️ Failed to load Bluesky auth settings: \(error)")
        }
    }

    /// Deletes Bluesky credentials from disk and clears in-memory state.
    override public func delete() async {
        await super.delete()
        did = nil
        handle = nil
        dpopPrivateKeyData = nil
    }

    // MARK: - Runtime Configuration

    override public func configure(with options: JSON?) {
        super.configure(with: options)

        if let value = options?["did"].string {
            did = value
        }
        if let value = options?["handle"].string {
            handle = value
        }
    }
}

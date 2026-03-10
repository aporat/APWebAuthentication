import Alamofire
import CryptoKit
import Foundation

// MARK: - BlueskyInterceptor

/// Request interceptor for the Bluesky / AT Protocol API.
///
/// Extends `OAuth2Interceptor` to add DPoP (Demonstrating Proof-of-Possession) support
/// required by the AT Protocol OAuth profile:
/// - Uses `DPoP` as the authorization scheme instead of `Bearer`
/// - Attaches a per-request DPoP proof JWT in the `DPoP` header
/// - Caches the server-issued `DPoP-Nonce` and injects it into subsequent proofs
/// - Retries once with a fresh nonce when the server responds with `use_dpop_nonce`
///
/// **Headers Added:**
/// ```
/// Authorization: DPoP <access_token>
/// DPoP: <signed_dpop_proof_jwt>
/// ```
///
/// **Example Usage:**
/// ```swift
/// let auth = BlueskyAuthentication()
/// auth.accessToken = "<access_token>"
///
/// let interceptor = BlueskyInterceptor(auth: auth)
/// let client = BlueskyAPIClient(auth: auth)
/// ```
///
/// - SeeAlso: [RFC 9449 – DPoP](https://www.rfc-editor.org/rfc/rfc9449)
public final class BlueskyInterceptor: OAuth2Interceptor, @unchecked Sendable {

    // MARK: - Properties

    /// The Bluesky authentication manager (typed for DPoP key access).
    private let blueskyAuth: BlueskyAuthentication

    /// The most recently received server-issued DPoP nonce, keyed by host.
    ///
    /// The server sends `DPoP-Nonce` in every response. We cache the value and
    /// include it in the next DPoP proof for the same host.
    private var dpopNonces: [String: String] = [:]

    // MARK: - Initialization

    /// Creates a new Bluesky request interceptor.
    ///
    /// - Parameter auth: The Bluesky authentication credentials.
    public init(auth: BlueskyAuthentication) {
        self.blueskyAuth = auth
        super.init(
            auth: auth,
            tokenLocation: .authorizationHeader,
            tokenParamName: "access_token",
            tokenHeaderParamName: "DPoP"
        )
    }

    // MARK: - RequestAdapter

    /// Adapts requests by adding the `DPoP` authorization scheme and a DPoP proof JWT.
    override public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
    ) {
        Task {
            var request = urlRequest

            // Add user agent if available
            if let ua = await blueskyAuth.userAgent, !ua.isEmpty {
                request.headers.add(.userAgent(ua))
            }

            let accessToken = await blueskyAuth.accessToken
            let privateKey = await blueskyAuth.dpopPrivateKey
            let method = request.method?.rawValue ?? "GET"
            let targetURL = request.url ?? URL(string: "https://bsky.social")!
            let host = targetURL.host ?? "bsky.social"
            let nonce = self.dpopNonces[host]

            // Add DPoP Authorization header
            if let token = accessToken, !token.isEmpty {
                request.headers.add(.authorization("DPoP \(token)"))
            }

            // Add Accept header
            request.headers.add(.accept("application/json"))

            // Build and attach DPoP proof
            do {
                let proof = try BlueskyDPoPManager.makeProof(
                    privateKey: privateKey,
                    method: method,
                    url: targetURL,
                    accessToken: accessToken,
                    nonce: nonce
                )
                request.headers.add(HTTPHeader(name: "DPoP", value: proof))
                completion(.success(request))
            } catch {
                completion(.failure(error))
            }
        }
    }


    // MARK: - Nonce Management

    /// Stores a server-issued DPoP nonce for the given host.
    ///
    /// Call this after successfully processing a response that contains a
    /// `DPoP-Nonce` header to ensure future requests include the updated nonce.
    ///
    /// - Parameters:
    ///   - nonce: The nonce value from the `DPoP-Nonce` response header.
    ///   - host: The server host the nonce belongs to.
    public func setDPoPNonce(_ nonce: String, for host: String) {
        dpopNonces[host] = nonce
    }
}

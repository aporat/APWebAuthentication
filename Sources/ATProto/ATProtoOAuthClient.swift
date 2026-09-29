import Alamofire
import CryptoKit
import Foundation
@preconcurrency import SwiftyJSON

// MARK: - Metadata & Responses

/// The subset of the authorization server metadata document the client needs
/// (`/.well-known/oauth-authorization-server`).
public struct ATProtoAuthorizationServerMetadata: Decodable, Sendable, Equatable {
    public let issuer: String
    public let authorizationEndpoint: URL
    public let tokenEndpoint: URL
    public let pushedAuthorizationRequestEndpoint: URL
    /// Optional per RFC 8414; sign-out revokes tokens here when present.
    public let revocationEndpoint: URL?

    enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case pushedAuthorizationRequestEndpoint = "pushed_authorization_request_endpoint"
        case revocationEndpoint = "revocation_endpoint"
    }

    public init(
        issuer: String,
        authorizationEndpoint: URL,
        tokenEndpoint: URL,
        pushedAuthorizationRequestEndpoint: URL,
        revocationEndpoint: URL? = nil
    ) {
        self.issuer = issuer
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.pushedAuthorizationRequestEndpoint = pushedAuthorizationRequestEndpoint
        self.revocationEndpoint = revocationEndpoint
    }
}

/// A token endpoint response, for the initial code exchange and for refreshes.
public struct ATProtoTokenResponse: Decodable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String?
    public let tokenType: String?
    public let expiresIn: Int?
    public let scope: String?
    /// The account DID. Present on every AT Protocol token response.
    public let sub: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
        case sub
    }

    public init(accessToken: String, refreshToken: String?, tokenType: String?, expiresIn: Int?, scope: String?, sub: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.scope = scope
        self.sub = sub
    }
}

/// What a pending login remembers between opening the browser and exchanging
/// the returned code.
public struct ATProtoAuthorizationRequest: Sendable {
    /// Where to send the user: `authorization_endpoint?client_id=…&request_uri=…`.
    public let authorizationURL: URL
    public let state: String
    public let codeVerifier: String
    public let metadata: ATProtoAuthorizationServerMetadata
    /// Set when the login started from a handle. The token's `sub` must match it.
    public let expectedDID: String?
}

/// The outcome of resolving a handle: its DID, its PDS, and the authorization
/// server that PDS delegates to.
public struct ATProtoIdentity: Sendable, Equatable {
    public let did: String
    /// The handle the DID document claims, verified against the one the user
    /// typed when the lookup started from a handle.
    public let handle: String?
    public let pdsURL: URL
    public let authorizationServer: URL
}

// MARK: - OAuth Client

/// Drives the AT Protocol OAuth profile for a native public client.
///
/// The flow, per https://atproto.com/specs/oauth:
/// 1. Resolve the handle to a DID, the DID to a PDS, and the PDS to its
///    authorization server (or start from a known entryway such as
///    `bsky.social` when the user did not give a handle).
/// 2. Push the authorization request (PAR) with PKCE and a DPoP proof; the
///    server replies with a `request_uri`.
/// 3. Send the user to `authorization_endpoint` with only `client_id` and
///    `request_uri`.
/// 4. Exchange the returned code at `token_endpoint`, again DPoP-bound, and
///    verify that the `sub` DID really belongs to this authorization server.
///
/// Every request to the authorization server carries a `DPoP` proof; the
/// server's `DPoP-Nonce` is tracked on the ``ATProtoAuthentication`` and a
/// `use_dpop_nonce` rejection is retried once with the fresh value.
@MainActor
public final class ATProtoOAuthClient {

    // MARK: - Well-Known Hosts

    /// Bluesky's entryway. Accounts hosted on `*.bsky.network` PDSes all
    /// authenticate here.
    public static let defaultAuthorizationServer = URL(string: "https://bsky.social")!

    /// Unauthenticated AppView, used for handle resolution.
    public static let publicAPI = URL(string: "https://public.api.bsky.app")!

    public static let plcDirectory = URL(string: "https://plc.directory")!

    // MARK: - Properties

    private let session: Session

    // MARK: - Initialization

    /// - Parameter session: Overridable for tests. The default is an
    ///   ephemeral session with no cookies and short timeouts.
    public init(session: Session? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpShouldSetCookies = false
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            self.session = Session(configuration: configuration)
        }
    }

    // MARK: - Discovery

    /// Normalises user input: strips `@`, whitespace, and a leading
    /// `https://bsky.app/profile/`, and appends `.bsky.social` to a bare name.
    public static func normalizeHandle(_ input: String) -> String {
        var handle = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://bsky.app/profile/", "http://bsky.app/profile/", "bsky.app/profile/", "@"] where handle.hasPrefix(prefix) {
            handle = String(handle.dropFirst(prefix.count))
        }
        if handle.hasSuffix("/") {
            handle = String(handle.dropLast())
        }
        if !handle.isEmpty, !handle.contains("."), !handle.hasPrefix("did:") {
            handle += ".bsky.social"
        }
        return handle
    }

    /// Resolves a handle to its DID via the public AppView. A DID passed in
    /// is returned unchanged.
    public func resolveHandle(_ handle: String) async throws(APWebAuthenticationError) -> String {
        if handle.hasPrefix("did:") {
            return handle
        }

        let url = Self.publicAPI
            .appendingPathComponent("xrpc/com.atproto.identity.resolveHandle")
            .appendingQueryParameters(["handle": handle])

        let json = try await getJSON(url, failureReason: "Unable to find that Bluesky handle.")
        guard let did = json["did"].string, did.hasPrefix("did:") else {
            throw .notFound
        }
        return did
    }

    /// Fetches the DID document and returns the `#atproto_pds` service endpoint.
    public func resolvePDS(did: String) async throws(APWebAuthenticationError) -> URL {
        let document = try await didDocument(for: did)
        guard let pds = Self.pdsEndpoint(in: document) else {
            throw .failed(reason: "The account's DID document lists no personal data server.")
        }
        return pds
    }

    /// Fetches the DID document for `did:plc` and `did:web` identities.
    public func didDocument(for did: String) async throws(APWebAuthenticationError) -> JSON {
        guard let documentURL = Self.didDocumentURL(for: did) else {
            throw .failed(reason: "Unsupported DID: \(did)")
        }
        return try await getJSON(documentURL, failureReason: "Unable to resolve the account's server.")
    }

    /// `did:plc:x` → `https://plc.directory/did:plc:x`;
    /// `did:web:example.com` → `https://example.com/.well-known/did.json`;
    /// `did:web:example.com:a:b` → `https://example.com/a/b/did.json`.
    static func didDocumentURL(for did: String) -> URL? {
        if did.hasPrefix("did:plc:") {
            return plcDirectory.appendingPathComponent(did)
        }
        guard did.hasPrefix("did:web:") else { return nil }

        let segments = did.dropFirst("did:web:".count).split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard let host = segments.first?.removingPercentEncoding, !host.isEmpty, !host.contains("/") else {
            return nil
        }
        let pathSegments = segments.dropFirst()
        guard pathSegments.allSatisfy({ !$0.isEmpty && !$0.contains("/") }) else { return nil }

        let path = pathSegments.isEmpty
            ? "/.well-known/did.json"
            : "/" + pathSegments.joined(separator: "/") + "/did.json"
        return URL(string: "https://\(host)\(path)")
    }

    /// The handles a DID document claims (`alsoKnownAs` entries of the form
    /// `at://handle`), lower-cased.
    static func handles(in document: JSON) -> [String] {
        document["alsoKnownAs"].arrayValue.compactMap { entry -> String? in
            guard let value = entry.string, value.hasPrefix("at://") else { return nil }
            let handle = value.dropFirst("at://".count)
            return handle.isEmpty ? nil : handle.lowercased()
        }
    }

    static func pdsEndpoint(in document: JSON) -> URL? {
        for service in document["service"].arrayValue {
            let id = service["id"].stringValue
            let type = service["type"].stringValue
            guard id.hasSuffix("#atproto_pds") || type == "AtprotoPersonalDataServer" else { continue }
            if let endpoint = service["serviceEndpoint"].string, let url = URL(string: endpoint), url.scheme == "https" {
                return url
            }
        }
        return nil
    }

    /// Reads `/.well-known/oauth-protected-resource` on the PDS and returns
    /// the authorization server it delegates to.
    public func authorizationServer(forResourceServer pds: URL) async throws(APWebAuthenticationError) -> URL {
        let url = pds.appendingPathComponent(".well-known/oauth-protected-resource")
        let json = try await getJSON(url, failureReason: "Unable to read the server's OAuth configuration.")
        guard let issuer = json["authorization_servers"].arrayValue.first?.string,
              let issuerURL = URL(string: issuer), issuerURL.scheme == "https" else {
            throw .failed(reason: "The server does not advertise an OAuth authorization server.")
        }
        return issuerURL
    }

    /// Reads `/.well-known/oauth-authorization-server` and checks it against
    /// what the AT Protocol OAuth profile requires of an authorization server.
    public func authorizationServerMetadata(issuer: URL) async throws(APWebAuthenticationError) -> ATProtoAuthorizationServerMetadata {
        let origin = Self.origin(of: issuer)
        guard let url = URL(string: origin + "/.well-known/oauth-authorization-server") else {
            throw .badRequest
        }

        let json = try await getJSON(url, failureReason: "Unable to read the authorization server's configuration.")
        let metadata: ATProtoAuthorizationServerMetadata
        do {
            metadata = try JSONDecoder().decode(ATProtoAuthorizationServerMetadata.self, from: json.rawData())
        } catch {
            throw .failed(reason: "The authorization server's configuration is incomplete.")
        }

        try Self.validate(json, metadata: metadata, fetchedFrom: origin)
        return metadata
    }

    /// The checks the reference clients make before trusting a server
    /// (https://atproto.com/specs/oauth, "Authorization Server Metadata").
    /// Each one guards a step this client relies on; failing early gives a
    /// message that names the problem instead of an opaque error mid-login.
    static func validate(_ json: JSON, metadata: ATProtoAuthorizationServerMetadata, fetchedFrom origin: String) throws(APWebAuthenticationError) {
        guard let issuerURL = URL(string: metadata.issuer),
              issuerURL.scheme == "https",
              issuerURL.port == nil,
              issuerURL.path.isEmpty || issuerURL.path == "/",
              issuerURL.query == nil, issuerURL.fragment == nil,
              Self.origin(of: issuerURL) == origin else {
            throw .failed(reason: "The authorization server's issuer does not match its address.")
        }

        func supports(_ key: String, _ value: String) -> Bool {
            json[key].arrayValue.contains { $0.string == value }
        }

        guard supports("response_types_supported", "code") else {
            throw .failed(reason: "The authorization server does not support the authorization code flow.")
        }
        guard supports("grant_types_supported", "authorization_code"),
              supports("grant_types_supported", "refresh_token") else {
            throw .failed(reason: "The authorization server does not support refresh tokens.")
        }
        guard supports("code_challenge_methods_supported", "S256") else {
            throw .failed(reason: "The authorization server does not support PKCE.")
        }
        guard supports("token_endpoint_auth_methods_supported", "none") else {
            throw .failed(reason: "The authorization server does not accept public clients.")
        }
        guard supports("dpop_signing_alg_values_supported", "ES256") else {
            throw .failed(reason: "The authorization server does not support DPoP with ES256.")
        }
        guard json["scopes_supported"].arrayValue.isEmpty || supports("scopes_supported", "atproto") else {
            throw .failed(reason: "The authorization server does not support the atproto scope.")
        }
        guard json["require_pushed_authorization_requests"].bool == true else {
            throw .failed(reason: "The authorization server does not require pushed authorization requests.")
        }
        guard json["authorization_response_iss_parameter_supported"].bool == true else {
            throw .failed(reason: "The authorization server does not identify itself on the callback.")
        }
        guard json["client_id_metadata_document_supported"].bool == true else {
            throw .failed(reason: "The authorization server does not support client metadata documents.")
        }
    }

    /// Handle → DID → PDS → authorization server, in one call.
    ///
    /// Resolution is bidirectional: the handle names a DID, and that DID's
    /// document must claim the handle back in `alsoKnownAs`. Anyone can point
    /// a handle's DNS at someone else's DID; only the DID's owner can make the
    /// document claim the handle, so a handle that fails the round trip is
    /// refused rather than shown as the account's name.
    public func resolveIdentity(handle: String) async throws(APWebAuthenticationError) -> ATProtoIdentity {
        let did = try await resolveHandle(handle)
        let document = try await didDocument(for: did)

        guard let pds = Self.pdsEndpoint(in: document) else {
            throw .failed(reason: "The account's DID document lists no personal data server.")
        }

        let claimedHandles = Self.handles(in: document)
        var verifiedHandle: String?
        if handle.hasPrefix("did:") {
            // The document names a handle; it only counts if that handle
            // resolves back to this DID, otherwise it is just a claim.
            if let claimed = claimedHandles.first {
                let resolved = try await resolveHandle(claimed)
                guard resolved == did else {
                    throw .failed(reason: "The handle \(claimed) does not resolve to \(did).")
                }
                verifiedHandle = claimed
            }
        } else {
            guard claimedHandles.contains(handle.lowercased()) else {
                throw .failed(reason: "The handle \(handle) does not belong to the account it points to.")
            }
            verifiedHandle = handle.lowercased()
        }

        let issuer = try await authorizationServer(forResourceServer: pds)
        return ATProtoIdentity(did: did, handle: verifiedHandle, pdsURL: pds, authorizationServer: issuer)
    }

    // MARK: - Authorization

    /// Pushes the authorization request and returns what the caller needs to
    /// open the browser and later finish the exchange.
    ///
    /// A fresh DPoP key is generated on `auth` for this login unless one is
    /// already present.
    ///
    /// - Parameters:
    ///   - loginHint: The handle to prefill on the server's login page.
    ///   - expectedDID: When resolved from a handle, the DID the session must end up bound to.
    ///   - state: Overridable for tests; a random value otherwise.
    public func beginAuthorization(
        auth: ATProtoAuthentication,
        metadata: ATProtoAuthorizationServerMetadata,
        loginHint: String? = nil,
        expectedDID: String? = nil,
        state: String? = nil
    ) async throws(APWebAuthenticationError) -> ATProtoAuthorizationRequest {
        guard let clientId = auth.clientId, !clientId.isEmpty,
              let redirectURL = auth.redirectURL, !redirectURL.isEmpty else {
            throw .failed(reason: "Missing OAuth client configuration.")
        }

        if auth.dpopKey == nil {
            auth.dpopKey = DPoPKey()
        }

        let state = state ?? Self.randomToken()
        let codeVerifier = Self.randomToken()
        let codeChallenge = Self.codeChallenge(for: codeVerifier)

        var form: [String: String] = [
            "client_id": clientId,
            "response_type": "code",
            "redirect_uri": redirectURL,
            "scope": auth.scope,
            "state": state,
            "code_challenge": codeChallenge,
            "code_challenge_method": "S256"
        ]
        if let loginHint, !loginHint.isEmpty {
            form["login_hint"] = loginHint
        }

        let json = try await dpopFormRequest(url: metadata.pushedAuthorizationRequestEndpoint, form: form, auth: auth)
        guard let requestURI = json["request_uri"].string, !requestURI.isEmpty else {
            throw .failed(reason: "The authorization server did not accept the login request.")
        }

        let authorizationURL = metadata.authorizationEndpoint.appendingQueryParameters([
            "client_id": clientId,
            "request_uri": requestURI
        ])

        return ATProtoAuthorizationRequest(
            authorizationURL: authorizationURL,
            state: state,
            codeVerifier: codeVerifier,
            metadata: metadata,
            expectedDID: expectedDID
        )
    }

    /// Validates the callback, exchanges the code, verifies the account, and
    /// stores the session on `auth`. On return `auth.isAuthorized` is true.
    public func completeAuthorization(
        callbackURL: URL,
        request: ATProtoAuthorizationRequest,
        auth: ATProtoAuthentication
    ) async throws(APWebAuthenticationError) {
        let params = callbackURL.parameters

        if let error = params["error"] {
            if error == "access_denied" {
                throw .canceled
            }
            throw .failed(reason: params["error_description"] ?? error)
        }

        guard params["state"] == request.state else {
            throw .failed(reason: "OAuth state mismatch — possible CSRF.")
        }

        // RFC 9207: the server names itself on the way back; refuse a mix-up.
        if let iss = params["iss"], Self.origin(of: iss) != Self.origin(of: request.metadata.issuer) {
            throw .failed(reason: "The login response came from an unexpected server.")
        }

        guard let code = params["code"], !code.isEmpty else {
            throw .failed(reason: "No authorization code received.")
        }

        guard let clientId = auth.clientId, let redirectURL = auth.redirectURL else {
            throw .failed(reason: "Missing OAuth client configuration.")
        }

        let token = try await tokenRequest(
            endpoint: request.metadata.tokenEndpoint,
            form: [
                "grant_type": "authorization_code",
                "code": code,
                "code_verifier": request.codeVerifier,
                "client_id": clientId,
                "redirect_uri": redirectURL
            ],
            auth: auth
        )

        guard let did = token.sub, did.hasPrefix("did:") else {
            throw .failed(reason: "The token response did not identify the account.")
        }

        // Bind the session to the account the user asked for, or, when the
        // login started at an entryway, to whatever account came back — but
        // only after checking that account really lives behind this issuer.
        if let expectedDID = request.expectedDID, expectedDID != did {
            throw .failed(reason: "Signed in to a different account than expected. Please try again.")
        }

        let document = try await didDocument(for: did)
        guard let pds = Self.pdsEndpoint(in: document) else {
            throw .failed(reason: "The account's DID document lists no personal data server.")
        }

        if request.expectedDID == nil {
            let issuer = try await authorizationServer(forResourceServer: pds)
            guard Self.origin(of: issuer) == Self.origin(of: request.metadata.issuer) else {
                throw .failed(reason: "The account is not hosted by the server that signed it in.")
            }
        }

        auth.apply(token)
        auth.did = did
        auth.pdsURL = pds
        // An entryway login never asked for a handle; the DID document knows it.
        if auth.handle == nil {
            auth.handle = Self.handles(in: document).first
        }
        auth.issuer = request.metadata.issuer
        auth.tokenEndpoint = request.metadata.tokenEndpoint
        auth.revocationEndpoint = request.metadata.revocationEndpoint
    }

    // MARK: - Refresh

    /// Exchanges the refresh token for a new pair and stores them on `auth`.
    ///
    /// Throws `.sessionExpired` when the server rejects the refresh token
    /// outright; the caller should then clear the session. Transient errors
    /// leave the stored tokens untouched.
    public func refresh(auth: ATProtoAuthentication) async throws(APWebAuthenticationError) {
        guard let refreshToken = auth.refreshToken, !refreshToken.isEmpty,
              let clientId = auth.clientId,
              let tokenEndpoint = auth.tokenEndpoint else {
            throw .sessionExpired(reason: nil)
        }

        let token = try await tokenRequest(
            endpoint: tokenEndpoint,
            form: [
                "grant_type": "refresh_token",
                "refresh_token": refreshToken,
                "client_id": clientId
            ],
            auth: auth
        )

        if let sub = token.sub, let did = auth.did, sub != did {
            throw .sessionExpired(reason: "The refreshed session belongs to a different account.")
        }

        auth.apply(token)
    }

    // MARK: - Revocation

    /// Revokes the session's tokens at the authorization server (RFC 7009),
    /// for sign-out and account removal. Best effort: a server that offers
    /// no `revocation_endpoint`, or one that is unreachable, does not stop
    /// the local sign-out. Returns how many tokens were revoked.
    @discardableResult
    public func revoke(auth: ATProtoAuthentication) async -> Int {
        guard let endpoint = auth.revocationEndpoint, let clientId = auth.clientId else {
            return 0
        }

        let tokens: [(hint: String, value: String?)] = [
            ("refresh_token", auth.refreshToken),
            ("access_token", auth.accessToken)
        ]

        var revoked = 0
        for (hint, value) in tokens {
            guard let value, !value.isEmpty else { continue }
            do {
                _ = try await dpopFormRequest(url: endpoint, form: [
                    "token": value,
                    "token_type_hint": hint,
                    "client_id": clientId
                ], auth: auth)
                revoked += 1
            } catch {
                Log.atproto.error("Revoking \(hint, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        return revoked
    }

    // MARK: - Token Endpoint

    private func tokenRequest(
        endpoint: URL,
        form: [String: String],
        auth: ATProtoAuthentication
    ) async throws(APWebAuthenticationError) -> ATProtoTokenResponse {
        let json = try await dpopFormRequest(url: endpoint, form: form, auth: auth)

        let token: ATProtoTokenResponse
        do {
            token = try JSONDecoder().decode(ATProtoTokenResponse.self, from: json.rawData())
        } catch {
            throw .failed(reason: "Unexpected token response.")
        }

        guard token.tokenType?.lowercased() == "dpop" else {
            throw .failed(reason: "The server issued a token that is not DPoP-bound.")
        }
        guard let scope = token.scope, scope.split(separator: " ").contains("atproto") else {
            throw .failed(reason: "The server did not grant the atproto scope.")
        }
        return token
    }

    // MARK: - DPoP Requests

    /// POSTs a form to the authorization server with a DPoP proof, tracking
    /// the server nonce and retrying once on `use_dpop_nonce`.
    private func dpopFormRequest(
        url: URL,
        form: [String: String],
        auth: ATProtoAuthentication
    ) async throws(APWebAuthenticationError) -> JSON {
        guard let key = auth.dpopKey else {
            throw .failed(reason: "Missing DPoP key.")
        }

        var attempt = 0
        while true {
            attempt += 1

            let proof: String
            do {
                proof = try key.proof(method: "POST", url: url, nonce: auth.authorizationServerNonce)
            } catch {
                throw .failed(reason: "Unable to sign the request.")
            }

            let headers: HTTPHeaders = [
                .contentType("application/x-www-form-urlencoded"),
                .accept("application/json"),
                HTTPHeader(name: "DPoP", value: proof)
            ]

            let response = await session.request(
                url,
                method: .post,
                parameters: form,
                encoder: URLEncodedFormParameterEncoder.default,
                headers: headers
            )
            .validate(statusCode: 200..<600)
            .serializingData()
            .response

            if let nonce = response.response?.value(forHTTPHeaderField: "DPoP-Nonce"), !nonce.isEmpty {
                auth.authorizationServerNonce = nonce
            }

            if let error = response.error {
                throw Self.transportError(error)
            }

            let status = response.response?.statusCode ?? 0
            let json = response.data.flatMap { try? JSON(data: $0) } ?? JSON.null

            if (200..<300).contains(status) {
                return json
            }

            let oauthError = json["error"].string
            if oauthError == "use_dpop_nonce", attempt == 1, auth.authorizationServerNonce != nil {
                Log.atproto.debug("Retrying with fresh DPoP nonce")
                continue
            }

            throw Self.oauthError(status: status, json: json)
        }
    }

    private func getJSON(_ url: URL, failureReason: String) async throws(APWebAuthenticationError) -> JSON {
        let response = await session.request(url, headers: [.accept("application/json")])
            .validate(statusCode: 200..<600)
            .serializingData()
            .response

        if let error = response.error {
            throw Self.transportError(error)
        }

        let status = response.response?.statusCode ?? 0
        let json = response.data.flatMap { try? JSON(data: $0) } ?? JSON.null

        guard (200..<300).contains(status) else {
            if status == 404 || status == 400 {
                throw .failed(reason: json["message"].string ?? failureReason, responseJSON: json)
            }
            if status >= 500 {
                throw .serverError(reason: failureReason, responseJSON: json)
            }
            throw .failed(reason: failureReason, responseJSON: json)
        }
        return json
    }

    // MARK: - Errors

    private static func transportError(_ error: AFError) -> APWebAuthenticationError {
        if error.isExplicitlyCancelledError {
            return .canceled
        }
        if let urlError = error.underlyingError as? URLError, urlError.code == .cancelled {
            return .canceled
        }
        return .connectionError(reason: NSLocalizedString("Check your network connection. Bluesky could also be down.", comment: ""))
    }

    private static func oauthError(status: Int, json: JSON) -> APWebAuthenticationError {
        let code = json["error"].string
        let description = json["error_description"].string ?? json["message"].string

        if status >= 500 {
            return .serverError(reason: description ?? "The authorization server is unavailable.", responseJSON: json)
        }
        if status == 429 {
            return .rateLimit(reason: description, responseJSON: json)
        }
        switch code {
        case "invalid_grant", "invalid_token":
            return .sessionExpired(reason: description, responseJSON: json)
        default:
            return .failed(reason: description ?? code ?? "Authorization failed.", responseJSON: json)
        }
    }

    // MARK: - Helpers

    static func origin(of url: URL) -> String {
        origin(of: url.absoluteString)
    }

    static func origin(of string: String) -> String {
        guard let components = URLComponents(string: string),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased() else {
            return string
        }
        if let port = components.port, !((scheme == "https" && port == 443) || (scheme == "http" && port == 80)) {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }

    /// 32 random bytes, base64url: a PKCE verifier or a `state` value.
    static func randomToken() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64URLEncodedString()
    }

    static func codeChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }
}

import Foundation
@preconcurrency import SwiftyJSON

/// Credentials for an AT Protocol OAuth session (Bluesky and other PDS hosts).
///
/// Holds everything a session needs to make authenticated XRPC calls and to
/// refresh itself: the DPoP-bound access and refresh tokens, the key they are
/// bound to, the account's DID and PDS, and the authorization server that
/// issued them. Persisted to the Keychain under the `atproto` category.
///
/// The `DPoP-Nonce` values are deliberately not persisted; servers rotate
/// them every few minutes and hand a fresh one back on the first request.
@MainActor
open class ATProtoAuthentication: Authentication {

    // MARK: - Settings Storage

    private struct AuthSettings: Codable, Sendable {
        let clientId: String?
        let redirectURL: String?
        let scope: String?
        let did: String?
        let handle: String?
        let pdsURL: String?
        let issuer: String?
        let tokenEndpoint: String?
        let revocationEndpoint: String?
        let accessToken: String?
        let refreshToken: String?
        let expiresAt: Date?
        let dpopKey: Data?
    }

    // MARK: - Client Configuration

    /// The client metadata document URL, which doubles as the OAuth `client_id`.
    public var clientId: String?

    /// The redirect URI registered in the client metadata document.
    public var redirectURL: String?

    /// Space-separated scopes. `atproto` is mandatory and is all this default
    /// asks for; an application layers the permissions it needs on top (see
    /// `BlueskyAPIClient.defaultScope`) before the login starts.
    public var scope: String = ATProtoAuthentication.defaultScope

    public static let defaultScope = "atproto"

    // MARK: - Account

    /// The account's DID, taken from the token response's `sub`.
    public var did: String?

    /// The handle the user typed at login, if any. Display only; the DID is
    /// the stable identifier.
    public var handle: String?

    /// The account's personal data server. Authenticated XRPC calls go here.
    public var pdsURL: URL?

    // MARK: - Authorization Server

    /// Origin of the authorization server that issued the tokens.
    public var issuer: String?

    /// Where refresh requests go.
    public var tokenEndpoint: URL?

    /// Where sign-out revokes the tokens, when the server offers it.
    public var revocationEndpoint: URL?

    // MARK: - Tokens

    public var accessToken: String?
    public var refreshToken: String?
    public var expiresAt: Date?

    /// The key the tokens are bound to. Lost key means a new login.
    public var dpopKey: DPoPKey?

    /// Latest nonce from the authorization server (PAR, token, refresh).
    public var authorizationServerNonce: String?

    /// Latest nonce from the PDS.
    public var resourceServerNonce: String?

    // MARK: - Initialization

    public required init() {}

    // MARK: - Authorization Status

    open var isAuthorized: Bool {
        guard let accessToken, !accessToken.isEmpty,
              let did, !did.isEmpty,
              dpopKey != nil else { return false }
        return true
    }

    /// True when the access token has expired or is about to. The interceptor
    /// refreshes ahead of a request rather than waiting for a 401.
    public var isAccessTokenExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSinceNow < 30
    }

    /// The `Authorization` header value for a resource request.
    public var authorizationHeaderValue: String? {
        guard let accessToken, !accessToken.isEmpty else { return nil }
        return "DPoP \(accessToken)"
    }

    // MARK: - Token Updates

    /// Applies a token endpoint response (initial exchange or refresh).
    public func apply(_ token: ATProtoTokenResponse) {
        accessToken = token.accessToken
        if let refreshed = token.refreshToken, !refreshed.isEmpty {
            refreshToken = refreshed
        }
        if let expiresIn = token.expiresIn {
            expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            expiresAt = nil
        }
        if let sub = token.sub, !sub.isEmpty {
            did = sub
        }
        if let granted = token.scope, !granted.isEmpty {
            scope = granted
        }
    }

    // MARK: - Persistence

    override open var keychainCategory: String { "atproto" }

    override open func save() async {
        let settings = AuthSettings(
            clientId: clientId,
            redirectURL: redirectURL,
            scope: scope,
            did: did,
            handle: handle,
            pdsURL: pdsURL?.absoluteString,
            issuer: issuer,
            tokenEndpoint: tokenEndpoint?.absoluteString,
            revocationEndpoint: revocationEndpoint?.absoluteString,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            dpopKey: dpopKey?.rawRepresentation
        )
        await saveSettings(settings)
    }

    override open func load() async {
        guard let settings = await loadSettings(AuthSettings.self) else { return }
        clientId = settings.clientId
        redirectURL = settings.redirectURL
        scope = settings.scope ?? Self.defaultScope
        did = settings.did
        handle = settings.handle
        pdsURL = settings.pdsURL.flatMap(URL.init(string:))
        issuer = settings.issuer
        tokenEndpoint = settings.tokenEndpoint.flatMap(URL.init(string:))
        revocationEndpoint = settings.revocationEndpoint.flatMap(URL.init(string:))
        accessToken = settings.accessToken
        refreshToken = settings.refreshToken
        expiresAt = settings.expiresAt
        dpopKey = settings.dpopKey.flatMap { try? DPoPKey(rawRepresentation: $0) }
    }

    override open func delete() async {
        await super.delete()
        did = nil
        handle = nil
        pdsURL = nil
        issuer = nil
        tokenEndpoint = nil
        revocationEndpoint = nil
        accessToken = nil
        refreshToken = nil
        expiresAt = nil
        dpopKey = nil
        authorizationServerNonce = nil
        resourceServerNonce = nil
    }

    /// Drops the tokens but keeps the client configuration, for when the
    /// authorization server has rejected a refresh for good.
    public func invalidateTokens() {
        accessToken = nil
        refreshToken = nil
        expiresAt = nil
    }

    // MARK: - Runtime Configuration

    /// Supported options, on top of ``Authentication/configure(with:)``:
    /// - `client_id`: client metadata document URL
    /// - `redirect_url`: registered redirect URI
    /// - `scope`: space-separated scopes
    override open func configure(with options: JSON?) {
        super.configure(with: options)

        if let value = options?["client_id"].string, !value.isEmpty {
            clientId = value
        }
        if let value = options?["redirect_url"].string, !value.isEmpty {
            redirectURL = value
        }
        if let value = options?["scope"].string, !value.isEmpty {
            scope = value
        }
    }
}

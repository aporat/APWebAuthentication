import Alamofire
import AuthenticationServices
import Foundation
@preconcurrency import SwiftyJSON

// MARK: - Configuration

/// Everything an OAuth 2.0 authorization code flow (RFC 6749 §4.1) with PKCE
/// (RFC 7636) needs to know about a provider and the app's registration.
///
/// Use a preset such as ``x(clientId:redirectURI:clientSecret:scopes:)`` or
/// fill one in for any standards-compliant provider.
public struct OAuth2AuthorizationCodeConfiguration: Sendable, Equatable {

    /// The provider's authorization endpoint.
    public var authorizeURL: URL

    /// The provider's token endpoint.
    public var tokenURL: URL

    /// The client id registered with the provider.
    public var clientId: String

    /// The client secret, for confidential clients. Leave `nil` for public
    /// clients (native apps using PKCE alone).
    public var clientSecret: String?

    /// How ``clientSecret`` reaches the token endpoint. Also governs whether a
    /// public client sends HTTP Basic with an empty password (Reddit).
    public var clientAuthentication: OAuth2ClientAuthentication

    /// The redirect URI registered with the provider. Sent verbatim on both
    /// the authorization and the token request.
    public var redirectURI: URL

    /// Scopes to request. Omitted from the authorization URL when empty.
    public var scopes: [String]

    /// Joins ``scopes``. RFC 6749 §3.3 says space; a few providers use `,`.
    public var scopeSeparator: String

    /// Extra query parameters for the authorization URL (`prompt`,
    /// `force_verify`, `login_hint`, …). They cannot override the parameters
    /// the flow sets itself (`response_type`, `client_id`, `redirect_uri`,
    /// `scope`, `state`, `code_challenge`, `code_challenge_method`).
    public var additionalAuthorizationParameters: [String: String]

    /// Whether to send a PKCE challenge. Leave on unless the provider
    /// rejects unknown parameters; servers without PKCE ignore it.
    public var usesPKCE: Bool

    public init(
        authorizeURL: URL,
        tokenURL: URL,
        clientId: String,
        redirectURI: URL,
        clientSecret: String? = nil,
        clientAuthentication: OAuth2ClientAuthentication = .requestBody,
        scopes: [String] = [],
        scopeSeparator: String = " ",
        additionalAuthorizationParameters: [String: String] = [:],
        usesPKCE: Bool = true
    ) {
        self.authorizeURL = authorizeURL
        self.tokenURL = tokenURL
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.clientAuthentication = clientAuthentication
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.scopeSeparator = scopeSeparator
        self.additionalAuthorizationParameters = additionalAuthorizationParameters
        self.usesPKCE = usesPKCE
    }
}

// MARK: - Provider Presets

public extension OAuth2AuthorizationCodeConfiguration {

    /// X (Twitter) OAuth 2.0 with PKCE, which X requires.
    ///
    /// Endpoints and scopes per
    /// https://docs.x.com/fundamentals/authentication/oauth-2-0/authorization-code.
    /// Scopes are space-separated; request `offline.access` to get a refresh
    /// token. Native apps are usually public clients (no secret); a
    /// confidential client's secret goes in HTTP Basic.
    static func x(
        clientId: String,
        redirectURI: URL,
        clientSecret: String? = nil,
        scopes: [String] = ["tweet.read", "users.read", "offline.access"]
    ) -> Self {
        Self(
            authorizeURL: URL(string: "https://x.com/i/oauth2/authorize")!,
            tokenURL: URL(string: "https://api.x.com/2/oauth2/token")!,
            clientId: clientId,
            redirectURI: redirectURI,
            clientSecret: clientSecret,
            clientAuthentication: .basicAuthorizationHeader,
            scopes: scopes
        )
    }

    /// GitHub (OAuth Apps and GitHub Apps), which has accepted PKCE `S256`
    /// since July 2025. GitHub has no public clients, so the token request
    /// always carries the client secret, in the body.
    static func gitHub(
        clientId: String,
        clientSecret: String,
        redirectURI: URL,
        scopes: [String] = []
    ) -> Self {
        Self(
            authorizeURL: URL(string: "https://github.com/login/oauth/authorize")!,
            tokenURL: URL(string: "https://github.com/login/oauth/access_token")!,
            clientId: clientId,
            redirectURI: redirectURI,
            clientSecret: clientSecret,
            clientAuthentication: .requestBody,
            scopes: scopes
        )
    }

    /// A Mastodon server. PKCE (`S256`) is supported from Mastodon 4.3; older
    /// servers ignore it. `clientId`/`clientSecret` come from registering the
    /// app on that server (`POST /api/v1/apps`).
    ///
    /// - Returns: `nil` when `host` is not a valid server hostname.
    static func mastodon(
        host: String,
        clientId: String,
        clientSecret: String?,
        redirectURI: URL,
        scopes: [String] = MastodonAPIClient.defaultScope.split(separator: " ").map(String.init)
    ) -> Self? {
        guard let host = MastodonAPIClient.normalizedHost(from: host),
              let authorizeURL = URL(string: "https://\(host)/oauth/authorize"),
              let tokenURL = URL(string: "https://\(host)/oauth/token") else {
            return nil
        }
        return Self(
            authorizeURL: authorizeURL,
            tokenURL: tokenURL,
            clientId: clientId,
            redirectURI: redirectURI,
            clientSecret: clientSecret,
            clientAuthentication: .requestBody,
            scopes: scopes
        )
    }
}

// MARK: - Pending Request

/// One login in progress: the URL to open and the secrets needed to finish it.
///
/// Keep it until the callback arrives. ``pkce`` holds the code verifier, so
/// don't log it or persist it anywhere less protected than the Keychain.
public struct OAuth2AuthorizationRequest: Sendable, Equatable {
    /// Where to send the user.
    public let url: URL
    /// The CSRF `state` the callback must echo back.
    public let state: String
    /// The PKCE pair, or `nil` when the configuration disables PKCE.
    public let pkce: PKCE?
    /// The redirect URI sent on the authorization request; reused on the token request.
    public let redirectURI: URL
}

// MARK: - Token Response

/// The token endpoint's answer to a successful code exchange.
public struct OAuth2TokenResponse: Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String?
    public let tokenType: String?
    /// Seconds until the access token expires, when the server said.
    public let expiresIn: TimeInterval?
    /// The granted scope, when the server reports it (it may differ from the request).
    public let scope: String?
    /// The full response body.
    public let json: JSON

    init?(json: JSON) {
        guard let accessToken = json["access_token"].string, !accessToken.isEmpty else {
            return nil
        }
        self.accessToken = accessToken
        self.refreshToken = json["refresh_token"].string.flatMap { $0.isEmpty ? nil : $0 }
        self.tokenType = json["token_type"].string
        if let number = json["expires_in"].number {
            self.expiresIn = number.doubleValue
        } else if let string = json["expires_in"].string {
            self.expiresIn = TimeInterval(string.trimmingCharacters(in: .whitespaces))
        } else {
            self.expiresIn = nil
        }
        self.scope = json["scope"].string
        self.json = json
    }
}

// MARK: - Flow

/// Runs the OAuth 2.0 authorization code flow with PKCE against any provider.
///
/// The whole flow in one call:
///
/// ```swift
/// let flow = OAuth2AuthorizationCodeFlow(configuration: .x(
///     clientId: "YOUR_CLIENT_ID",
///     redirectURI: URL(string: "myapp://oauth/x")!
/// ))
/// let auth = Auth2Authentication()
/// auth.accountIdentifier = "x"
/// try await flow.signIn(auth: auth, contextProvider: self)
/// let client = XAPIClient(auth: auth)
/// ```
///
/// Or step by step, for apps that present the page themselves:
/// ``makeAuthorizationRequest(state:pkce:)`` →  open `request.url` →
/// ``authorizationCode(from:for:)`` → ``exchangeCode(_:for:)`` (or
/// ``completeAuthorization(callbackURL:request:auth:)`` for the last two
/// plus storing the tokens).
@MainActor
public final class OAuth2AuthorizationCodeFlow {

    // MARK: - Properties

    public let configuration: OAuth2AuthorizationCodeConfiguration

    private let session: Session

    // MARK: - Initialization

    /// - Parameters:
    ///   - configuration: The provider and app registration.
    ///   - session: Overridable for tests. The default is an ephemeral
    ///     session with no cookies and short timeouts.
    public init(configuration: OAuth2AuthorizationCodeConfiguration, session: Session? = nil) {
        self.configuration = configuration
        if let session {
            self.session = session
        } else {
            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.httpShouldSetCookies = false
            sessionConfiguration.timeoutIntervalForRequest = 20
            sessionConfiguration.timeoutIntervalForResource = 30
            self.session = Session(configuration: sessionConfiguration)
        }
    }

    // MARK: - Step 1: Authorization URL

    /// Builds the authorization URL with `response_type=code`, a random
    /// `state` and, unless disabled, a PKCE `S256` challenge.
    ///
    /// - Parameters:
    ///   - state: Overridable for tests; a random value otherwise.
    ///   - pkce: Overridable for tests; a fresh pair otherwise.
    public func makeAuthorizationRequest(state: String? = nil, pkce: PKCE? = nil) -> OAuth2AuthorizationRequest {
        let state = state ?? PKCE.generateVerifier()
        let pkce = configuration.usesPKCE ? (pkce ?? PKCE()) : nil

        var items: [(String, String)] = [
            ("response_type", "code"),
            ("client_id", configuration.clientId),
            ("redirect_uri", configuration.redirectURI.absoluteString)
        ]
        if !configuration.scopes.isEmpty {
            items.append(("scope", configuration.scopes.joined(separator: configuration.scopeSeparator)))
        }
        items.append(("state", state))
        if let pkce {
            items.append(("code_challenge", pkce.challenge))
            items.append(("code_challenge_method", PKCE.method))
        }

        let reserved = Set(items.map { $0.0 }).union(["code_challenge", "code_challenge_method", "scope"])
        for (name, value) in configuration.additionalAuthorizationParameters.sorted(by: { $0.key < $1.key })
            where !reserved.contains(name) {
            items.append((name, value))
        }

        return OAuth2AuthorizationRequest(
            url: Self.url(configuration.authorizeURL, appending: items),
            state: state,
            pkce: pkce,
            redirectURI: configuration.redirectURI
        )
    }

    // MARK: - Step 2: Callback

    /// Validates the redirect and returns its authorization code.
    ///
    /// Checks, in order: the URL is the registered redirect (scheme, host,
    /// port, path), `state` matches (before anything else in the callback is
    /// trusted, including `error=`), then the provider's `error`.
    ///
    /// - Throws: `.canceled` for `error=access_denied`; `.failed` for a
    ///   foreign URL, a state mismatch, any other `error`, or a missing code.
    public func authorizationCode(
        from callbackURL: URL,
        for request: OAuth2AuthorizationRequest
    ) throws(APWebAuthenticationError) -> String {
        guard WebAuthRedirectHandler.urlMatchesRedirect(callbackURL, redirect: request.redirectURI) else {
            throw .failed(reason: "The login returned to an unexpected address.")
        }

        let params = callbackURL.parameters

        guard let state = params["state"], state == request.state else {
            throw .failed(reason: "OAuth state mismatch — possible CSRF.")
        }

        if let error = params["error"] {
            if error == "access_denied" {
                throw .canceled
            }
            throw .failed(reason: params["error_description"] ?? error)
        }

        guard let code = params["code"], !code.isEmpty else {
            throw .failed(reason: "No authorization code received.")
        }
        return code
    }

    // MARK: - Step 3: Code Exchange

    /// Exchanges an authorization code for tokens.
    public func exchangeCode(
        _ code: String,
        for request: OAuth2AuthorizationRequest
    ) async throws(APWebAuthenticationError) -> OAuth2TokenResponse {
        try await exchangeCode(code, codeVerifier: request.pkce?.verifier, redirectURI: request.redirectURI)
    }

    /// Exchanges an authorization code for tokens: a form POST to the token
    /// endpoint with `grant_type=authorization_code`, `code`, `redirect_uri`,
    /// `client_id`, `code_verifier` (when given) and the client secret per
    /// ``OAuth2AuthorizationCodeConfiguration/clientAuthentication``.
    ///
    /// - Parameters:
    ///   - redirectURI: Must equal the one on the authorization request;
    ///     defaults to the configuration's.
    public func exchangeCode(
        _ code: String,
        codeVerifier: String?,
        redirectURI: URL? = nil
    ) async throws(APWebAuthenticationError) -> OAuth2TokenResponse {
        var parameters: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": (redirectURI ?? configuration.redirectURI).absoluteString
        ]
        if let codeVerifier {
            parameters["code_verifier"] = codeVerifier
        }
        // Ask for JSON explicitly: GitHub answers form-encoded otherwise.
        var headers: HTTPHeaders = [
            .contentType("application/x-www-form-urlencoded"),
            .accept("application/json")
        ]
        configuration.clientAuthentication.apply(
            clientId: configuration.clientId,
            clientSecret: configuration.clientSecret,
            to: &parameters,
            headers: &headers
        )

        Log.oauth.debug("Exchanging authorization code at \(self.configuration.tokenURL.host ?? "?", privacy: .public)")

        let response = await session.request(
            configuration.tokenURL,
            method: .post,
            parameters: parameters,
            encoder: URLEncodedFormParameterEncoder.default,
            headers: headers
        )
        .validate(statusCode: 200..<600)
        .serializingData()
        .response

        if let error = response.error {
            throw Self.transportError(error)
        }

        let status = response.response?.statusCode ?? 0
        let json = response.data.flatMap { try? JSON(data: $0) } ?? JSON.null

        // GitHub reports failures with HTTP 200 and an `error` field.
        if !(200..<300).contains(status) || json["error"].string != nil {
            throw Self.tokenError(status: status, json: json)
        }

        guard let token = OAuth2TokenResponse(json: json) else {
            throw .failed(reason: "The token response did not include an access token.", responseJSON: json)
        }
        return token
    }

    // MARK: - Steps 2 + 3 + Storage

    /// Validates the callback, exchanges the code and stores the result on
    /// `auth`: `clientId`/`clientSecret` from the configuration (so the
    /// refresh path in ``OAuth2Interceptor`` can use them), then the tokens
    /// via ``Auth2Authentication/applyTokenResponse(_:now:)``, then
    /// ``Auth2Authentication/save()``.
    @discardableResult
    public func completeAuthorization(
        callbackURL: URL,
        request: OAuth2AuthorizationRequest,
        auth: Auth2Authentication
    ) async throws(APWebAuthenticationError) -> OAuth2TokenResponse {
        let code = try authorizationCode(from: callbackURL, for: request)
        let token = try await exchangeCode(code, for: request)

        auth.clientId = configuration.clientId
        auth.clientSecret = configuration.clientSecret
        auth.applyTokenResponse(token.json)
        await auth.save()
        return token
    }

    // MARK: - All Steps

    /// Runs the whole flow in an `ASWebAuthenticationSession` and stores the
    /// tokens on `auth`.
    ///
    /// The session completes on ``OAuth2AuthorizationCodeConfiguration/redirectURI``:
    /// an `https` redirect is matched by host and path (a universal link the
    /// app's associated domains must cover), anything else by its scheme.
    ///
    /// - Parameter ephemeral: Don't share cookies with Safari.
    @discardableResult
    public func signIn(
        auth: Auth2Authentication,
        contextProvider: ASWebAuthenticationPresentationContextProviding,
        ephemeral: Bool = false
    ) async throws(APWebAuthenticationError) -> OAuth2TokenResponse {
        let request = makeAuthorizationRequest()
        let redirect = configuration.redirectURI

        let callbackURL: URL
        if redirect.scheme?.lowercased() == "https", let host = redirect.host {
            callbackURL = try await ASWebAuthenticationSession.start(
                url: request.url,
                callback: .https(host: host, path: redirect.path.isEmpty ? "/" : redirect.path),
                contextProvider: contextProvider,
                ephemeral: ephemeral
            )
        } else if let scheme = redirect.scheme {
            callbackURL = try await ASWebAuthenticationSession.start(
                url: request.url,
                callbackURLScheme: scheme,
                contextProvider: contextProvider,
                ephemeral: ephemeral
            )
        } else {
            throw .failed(reason: "The redirect URI has no scheme.")
        }

        return try await completeAuthorization(callbackURL: callbackURL, request: request, auth: auth)
    }

    /// Runs the whole flow in the in-app web view (``APWebAuthSession``) and
    /// stores the tokens on `auth`. Configure `webSession` (presentation
    /// context, appearance) first; this sets its `expectedState`.
    @discardableResult
    public func signIn(
        auth: Auth2Authentication,
        webSession: APWebAuthSession
    ) async throws(APWebAuthenticationError) -> OAuth2TokenResponse {
        let request = makeAuthorizationRequest()
        webSession.expectedState = request.state
        let (callbackURL, _) = try await webSession.start(url: request.url, callbackURL: request.redirectURI)
        return try await completeAuthorization(callbackURL: callbackURL, request: request, auth: auth)
    }

    // MARK: - Helpers

    /// Appends `items` to `base`'s query, percent-encoding everything outside
    /// the unreserved set so `+`, `&` and spaces survive any server's parser.
    static func url(_ base: URL, appending items: [(String, String)]) -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base
        }
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        func encode(_ string: String) -> String {
            string.addingPercentEncoding(withAllowedCharacters: unreserved) ?? string
        }
        var query = components.percentEncodedQuery.map { [$0] } ?? []
        query += items.map { "\(encode($0.0))=\(encode($0.1))" }
        components.percentEncodedQuery = query.joined(separator: "&")
        return components.url ?? base
    }

    private static func transportError(_ error: AFError) -> APWebAuthenticationError {
        if error.isExplicitlyCancelledError {
            return .canceled
        }
        if let urlError = error.underlyingError as? URLError {
            switch urlError.code {
            case .cancelled:
                return .canceled
            case .timedOut:
                return .timeout
            default:
                break
            }
        }
        return .connectionError(reason: String(localized: "Check your network connection.", comment: ""))
    }

    private static func tokenError(status: Int, json: JSON) -> APWebAuthenticationError {
        let code = json["error"].string
        let description = json["error_description"].string ?? json["message"].string

        if status >= 500 {
            return .serverError(reason: description ?? "The authorization server is unavailable.", responseJSON: json)
        }
        if status == 429 {
            return .rateLimit(reason: description, responseJSON: json)
        }
        return .failed(reason: description ?? code ?? "Token request failed (HTTP \(status)).", responseJSON: json)
    }
}

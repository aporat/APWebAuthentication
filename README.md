# APWebAuthentication

A Swift package for in-app OAuth 1.0a and OAuth 2.0 authentication on iOS. Presents a `WKWebView`-backed sign-in flow, validates the redirect, parses the callback, and persists credentials to the Keychain.

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Faporat%2FAPWebAuthentication%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/aporat/APWebAuthentication)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Faporat%2FAPWebAuthentication%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/aporat/APWebAuthentication)
![CI](https://github.com/aporat/APWebAuthentication/actions/workflows/ci.yml/badge.svg)
[![codecov](https://codecov.io/github/aporat/APWebAuthentication/graph/badge.svg?token=OHF9AE0KMC)](https://codecov.io/github/aporat/APWebAuthentication)

## Features

- OAuth 1.0a (RFC 5849) and OAuth 2.0 request signing via `Alamofire` interceptors
- Hosted sign-in UI (`WebAuthViewController`) with normal and Safari-style chrome
- Strict component-based redirect-URL matching and OAuth `state` CSRF validation
- OAuth 2.0 authorization code flow with PKCE (RFC 7636) and code exchange, with presets for X, GitHub and Mastodon
- Automatic refresh-token grant on 401 with single-flight queueing
- Keychain-backed credential storage (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`)
- Configurable tint colors and per-account browser/user-agent modes
- Cookie-based ("session") flows for providers that don't speak OAuth (Pinterest Web)

## Requirements

- iOS 18.0+
- Swift 6 (strict concurrency)

## Installation

Add the package to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/aporat/APWebAuthentication.git", from: "3.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies…** and paste the URL.

## OAuth 2.0 authorization code with PKCE

`OAuth2AuthorizationCodeFlow` runs the whole authorization code flow: it builds the authorization URL (`response_type=code`, a random `state`, an `S256` PKCE challenge), presents it, checks the callback, exchanges the code with the `code_verifier`, and stores the tokens on an `Auth2Authentication`.

```swift
import APWebAuthentication
import AuthenticationServices
import UIKit

@MainActor
final class XLogin: NSObject, ASWebAuthenticationPresentationContextProviding {
    weak var window: UIWindow?

    func signIn() async throws -> XAPIClient {
        let flow = OAuth2AuthorizationCodeFlow(configuration: .x(
            clientId: "YOUR_CLIENT_ID",
            redirectURI: URL(string: "myapp://oauth/x")!,
            scopes: ["tweet.read", "users.read", "offline.access"]
        ))

        let auth = Auth2Authentication()
        auth.accountIdentifier = "x"
        try await flow.signIn(auth: auth, contextProvider: self)   // saves to the Keychain

        return XAPIClient(auth: auth)   // refreshes with the stored refresh token
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        window ?? ASPresentationAnchor()
    }
}
```

`signIn(auth:contextProvider:ephemeral:)` uses `ASWebAuthenticationSession`. A custom-scheme redirect is matched by scheme; an `https` redirect is matched by host and path, so it must be a universal link your app's associated domains cover. `signIn(auth:webSession:)` uses the in-app `APWebAuthSession` web view instead.

The callback is checked in this order: the URL must be the registered redirect, `state` must match (before anything else is trusted, including `error=`), then the provider's error. `error=access_denied` throws `.canceled`; every other failure is an `APWebAuthenticationError`. The verifier, code and tokens are never logged.

**Presets**

| Preset | Endpoints | Client authentication |
|---|---|---|
| `.x(clientId:redirectURI:clientSecret:scopes:)` | `x.com/i/oauth2/authorize`, `api.x.com/2/oauth2/token` | none for public clients, Basic for confidential |
| `.gitHub(clientId:clientSecret:redirectURI:scopes:)` | `github.com/login/oauth/authorize`, `github.com/login/oauth/access_token` | secret in the body (GitHub has no public clients) |
| `.mastodon(host:clientId:clientSecret:redirectURI:scopes:)` | `https://<host>/oauth/authorize`, `/oauth/token` | secret in the body; PKCE needs Mastodon 4.3+ |

Any other provider: fill in `OAuth2AuthorizationCodeConfiguration` (`authorizeURL`, `tokenURL`, `clientId`, `redirectURI`, optional `clientSecret` and `clientAuthentication`, `scopes`, `scopeSeparator`, `additionalAuthorizationParameters`, `usesPKCE`).

**Custom UI.** Each step is public:

```swift
let request = flow.makeAuthorizationRequest()      // request.url, request.state, request.pkce
// … open request.url yourself, receive callbackURL …
let code = try flow.authorizationCode(from: callbackURL, for: request)
let token = try await flow.exchangeCode(code, for: request)   // OAuth2TokenResponse
auth.applyTokenResponse(token.json)
// or both steps plus storage: try await flow.completeAuthorization(callbackURL:request:auth:)
```

`PKCE` is public too: `PKCE()` makes a random pair, `PKCE(verifier:)` rebuilds one, `PKCE.challenge(for:)` computes `S256`.

## Quick start: OAuth 2.0 with state validation

```swift
import APWebAuthentication
import UIKit

@MainActor
final class GitHubLogin: NSObject, APWebAuthenticationPresentationContextProviding {
    weak var anchor: UIViewController?

    func signIn() async throws {
        // 1. Build the authorization URL with a freshly generated state.
        let state = WebAuthRedirectHandler.generateState()
        var components = URLComponents(string: "https://github.com/login/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: "YOUR_CLIENT_ID"),
            URLQueryItem(name: "redirect_uri", value: "myapp://github-callback"),
            URLQueryItem(name: "scope", value: "user repo"),
            URLQueryItem(name: "state", value: state)
        ]
        let authURL = components.url!
        let callbackURL = URL(string: "myapp://github-callback")!

        // 2. Configure the session and validate the state on the callback.
        let session = APWebAuthSession(accountType: AccountStore.github)
        session.presentationContextProvider = self
        session.appearanceStyle = .safari

        let vc = WebAuthViewController(authURL: authURL, redirectURL: callbackURL)
        vc.expectedState = state              // <- CSRF guard
        session.loginViewController = vc

        // 3. Start. Throws on cancel, network failure, error= callback, or state mismatch.
        let (resultURL, _) = try await session.start()

        // 4. Pull the `code` out of the redirect; exchange it for tokens on your server.
        let code = resultURL.parameters["code"] ?? ""
        try await exchangeCodeForTokens(code)
    }

    func presentationAnchor(for session: APWebAuthSession) -> UIViewController? { anchor }
}
```

## Storing credentials

`Auth1Authentication` and `Auth2Authentication` persist all secrets to the Keychain. Set properties, call `save()`, retrieve later with `load()`.

```swift
let auth = Auth2Authentication()
auth.accountIdentifier = "github"
auth.clientId = "..."
auth.clientSecret = "..."
auth.accessToken = "ya29..."
auth.refreshToken = "1//0..."
await auth.save()    // writes to Keychain

// Later, in a new session:
let restored = Auth2Authentication()
restored.accountIdentifier = "github"
await restored.load()
print(restored.isAuthorized) // true
```

`delete()` removes the Keychain entry for that account. No data ever lands in `Documents/`.

## Authenticated network requests

Use the OAuth interceptors with `Alamofire`:

```swift
import Alamofire
import SwiftyJSON

// OAuth 2.0 — bearer token in the Authorization header (the default
// `tokenLocation`), auto-refresh on 401
let interceptor = OAuth2Interceptor(
    auth: auth,
    refreshTokenURL: "https://github.com/login/oauth/access_token"
)

let session = Session(interceptor: interceptor)
let data = try await session
    .request("https://api.github.com/user")
    .validate()
    .serializingData()
    .value
let user = GitHubUser(info: try JSON(data: data)) // nil if the payload has no "id"
```

The bundled provider clients wrap the same plumbing and return SwiftyJSON values; the user models are built from that JSON:

```swift
let client = GitHubAPIClient(auth: auth)
let json = try await client.request("/user")   // throws APWebAuthenticationError
let user = GitHubUser(info: json)
```

When a request returns 401 and `refreshTokenURL` is set, the interceptor exchanges the refresh token, retries every in-flight request once, and only clears the stored tokens when the token endpoint answers `invalid_grant` (RFC 6749 §5.2). Any other failure — `invalid_client`, a 5xx, a timeout, a non-JSON body — keeps the session intact.

The interceptor also refreshes **before** a token expires. `Auth2Authentication.expiresAt` is set from `expires_in` on every refresh and persisted with the other credentials. When you store the first token yourself, call `auth.applyTokenResponse(json)` with the token endpoint's JSON, or with `JSON(callbackURL.parameters)` for an implicit-flow callback. That sets `accessToken`, `refreshToken` and `expiresAt`. When a request is about to go out and the token expires within `refreshLeeway` (60 s by default) or already has, the interceptor refreshes it first. Concurrent requests share one refresh, and the request is sent with the new token. If that refresh fails, the request is sent with the current token, the 401 path above still applies, and proactive attempts pause for `proactiveRefreshBackoff` (30 s). With no known `expiresAt`, only the 401 path is used.

```swift
let interceptor = OAuth2Interceptor(
    auth: auth,
    refreshTokenURL: "https://api.example.com/oauth2/token",
    refreshLeeway: 120            // refresh up to 2 minutes early
)
```

`tokenLocation` defaults to `.authorizationHeader` (`Authorization: Bearer …`, RFC 6750). APIs that want the token as a query parameter must opt in with `tokenLocation: .params` (and `tokenParamName:` if it isn't `access_token`), as `FoursquareInterceptor` does.

When used through an `AuthClient` subclass, credentials (bearer tokens, DPoP proofs, CSRF headers, OAuth 1.0a signatures) are only attached to requests for the host of `baseURLString` — add any other host that should receive them to `additionalAuthorizedHosts`. Absolute URLs on other hosts are sent unauthenticated. A bare `Session(interceptor:)` as above applies no such restriction.

OAuth 1.0a works the same way:

```swift
let auth1 = Auth1Authentication()
auth1.consumerKey = "..."; auth1.consumerSecret = "..."
auth1.token = "..."; auth1.secret = "..."

let session = Session(interceptor: OAuth1Interceptor(auth: auth1))
```

`OAuth1Interceptor` follows RFC 5849 §3.4.1: form bodies, query items, and fragment params are all included in the signature base — duplicate keys (e.g. `scope=a&scope=b`) survive.

## Customizing the sign-in UI

Tint colors are configured once at app launch and apply to every presented session:

```swift
APWebAuthSession.setTintColor(.systemBlue)
APWebAuthSession.setBarTintColor(.systemBackground)
```

Both fall back to `UIColor(named: "TintColor")` / `"BarTintColor"` from your asset catalog when no override is supplied, and to system defaults when neither exists.

Per-session knobs:

```swift
session.appearanceStyle = .safari          // or .normal
session.statusBarStyle = .lightContent
auth.browserMode = .iosChrome              // user-agent profile
auth.customUserAgent = "MyApp/2.0"
```

## Intercepting tokens from a web flow

`WebTokenInterceptorViewController` loads a URL, injects an `XMLHttpRequest` hook, and surfaces every matching request via a delegate — useful for providers that emit tokens in JavaScript rather than as a redirect.

```swift
let config = WebTokenInterceptorConfiguration(
    url: URL(string: "https://example.com/login")!,
    targetURL: URL(string: "https://example.com/api/token")!,
    isInteractive: true
)
let vc = WebTokenInterceptorViewController(configuration: config)
vc.delegate = self
present(UINavigationController(rootViewController: vc), animated: true)
try await vc.start()
```

```swift
extension MyCoordinator: WebTokenInterceptorDelegate {
    func webTokenInterceptor(
        _ controller: WebTokenInterceptorViewController,
        didIntercept request: InterceptedRequest
    ) async {
        if let auth = request.requestHeaders["Authorization"] {
            // Stash the bearer token, etc.
        }
    }
}
```

## Built-in providers

The package ships an API client and user model for each of these providers, under the matching subdirectory of `Sources/`:

| Provider | Client | Auth |
|---|---|---|
| X (Twitter) | `XAPIClient` | OAuth 2.0 |
| Reddit | `RedditAPIClient` | OAuth 2.0 |
| Pinterest | `PinterestAPIClient` | OAuth 2.0 |
| Pinterest (web session) | `PinterestWebAPIClient`, `PinterestWebHTMLAPIClient` | Cookie session |
| GitHub | `GitHubAPIClient` | OAuth 2.0 |
| Tumblr | `TumblrAPIClient` | OAuth 2.0 |
| Twitch | `TwitchAPIClient` | OAuth 2.0 |
| Foursquare | `FoursquareAPIClient` | OAuth 2.0 |
| Mastodon | `MastodonAPIClient` | OAuth 2.0 (per instance) |
| Bluesky | `BlueskyAPIClient` (on `ATProto/`) | AT Protocol OAuth (PAR + PKCE + DPoP) |

`AccountStore` holds the matching `AccountType` entries.

Adding a new provider is a matter of declaring an `AccountType`, attaching an `OAuth1Interceptor` or `OAuth2Interceptor`, and writing a thin API client over `Alamofire.Session`.

## Errors

All authentication paths surface `APWebAuthenticationError`:

```swift
do {
    let (url, cookies) = try await session.start()
} catch APWebAuthenticationError.canceled {
    // User dismissed the web view.
} catch let error as APWebAuthenticationError {
    print(error.errorTitle, error.errorDescription ?? "")
}
```

Useful classifiers on the error: `isRetryable`, `isLoginError`, `requiresUserAction`, `isCancelledError`.

## Architecture

| Type | Role |
| --- | --- |
| `APWebAuthSession` | Orchestrates the sign-in flow; presents the web VC; returns the callback URL + cookies. |
| `WebAuthViewController` | `WKWebView`-backed sign-in screen. Owns the redirect handler. |
| `WebAuthRedirectHandler` | Strict scheme/host/port/path matching; CSRF state validation; response parsing. |
| `Authentication` / `Auth1Authentication` / `Auth2Authentication` | Credential models with Keychain persistence. |
| `OAuth2AuthorizationCodeFlow` / `PKCE` | Authorization code flow with PKCE: URL building, callback validation, code exchange. |
| `OAuth1Interceptor` / `OAuth2Interceptor` | Alamofire interceptors that sign requests and refresh tokens. |
| `SessionAuthentication` | Cookie-based auth (for providers without OAuth). Cookies live in the Keychain too. |
| `WebTokenInterceptorViewController` | Captures tokens from in-page XHR calls. |
| `KeychainStore` | Low-level Keychain wrapper used by every credential type. |

## Testing

```bash
xcodebuild -scheme APWebAuthentication \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Some Keychain-touching tests skip when run from a SwiftPM test host without an `application-identifier` entitlement — that's the only environment where this happens; real apps embedding the library exercise the full code path normally.

## License

MIT — see [LICENSE](LICENSE).

## Author

Built by [Aporat](https://github.com/aporat). PRs welcome.

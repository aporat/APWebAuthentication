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
- Automatic refresh-token grant on 401 with single-flight queueing
- Keychain-backed credential storage (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`)
- Configurable tint colors and per-account browser/user-agent modes
- Cookie-based ("session") flows for providers that don't speak OAuth (Pinterest Web, TikTok Web)

## Requirements

- iOS 18+
- Swift 6 (strict concurrency)

## Installation

Add the package to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/aporat/APWebAuthentication.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies…** and paste the URL.

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

// OAuth 2.0 — bearer token, auto-refresh on 401
let interceptor = OAuth2Interceptor(
    auth: auth,
    tokenLocation: .authorizationHeader,
    refreshTokenURL: "https://github.com/login/oauth/access_token"
)

let session = Session(interceptor: interceptor)
let user: GitHubUser = try await session
    .request("https://api.github.com/user")
    .serializingDecodable(GitHubUser.self)
    .value
```

When a request returns 401 and `refreshTokenURL` is set, the interceptor exchanges the refresh token, retries every in-flight request once, and only clears the stored tokens on a definitive 400/401 from the token endpoint (transient errors keep the session intact).

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

`AccountStore` ships configured `AccountType` entries for X (Twitter), Reddit, Pinterest, GitHub, Tumblr, Twitch, TikTok, Foursquare, 500px, and Instagram. Each provider has its own API client and user model under the matching subdirectory (`X/`, `Reddit/`, etc.) — see `Sources/`.

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
| `OAuth1Interceptor` / `OAuth2Interceptor` | Alamofire interceptors that sign requests and refresh tokens. |
| `SessionAuthentication` | Cookie-based auth (for providers without OAuth). Cookies live in the Keychain too. |
| `WebTokenInterceptorViewController` | Captures tokens from in-page XHR calls. |
| `KeychainStore` | Low-level Keychain wrapper used by every credential type. |

## Testing

```bash
xcodebuild -scheme APWebAuthentication \
    -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Some Keychain-touching tests skip when run from a SwiftPM test host without an `application-identifier` entitlement — that's the only environment where this happens; real apps embedding the library exercise the full code path normally.

## License

MIT — see [LICENSE](LICENSE).

## Author

Built by [Aporat](https://github.com/aporat). PRs welcome.

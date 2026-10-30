# Changelog

## [Unreleased]

### Breaking changes

- The minimum deployment target is iOS 18.0 (was 17.4). iOS 18 runs on the
  same devices as iOS 17, so no hardware is dropped.
- JGProgressHUD is no longer a dependency. `WebAuthViewController.showHUD()`
  / `hideHUD()` draw their own spinner.
- `ASWebAuthenticationSession.start(url:callbackURLScheme:...)` was removed;
  pass `callback: .customScheme(scheme)` to `start(url:callback:...)`.

### Fixed

- `WebAuthViewController` and `WebTokenInterceptorViewController` no longer
  flash a white page before the first frame paints. The web view and the
  controller's view now follow the system background (`.systemBackground`),
  so a sheet opened in dark mode is dark while it loads.

## [3.0.0] - 2026-10-10

### Breaking changes

- **APUserAgentGenerator 2.0.** The dependency is now pinned with
  `from: "2.0.0"` instead of `branch: "main"`, so APWebAuthentication itself
  can be installed with a version requirement, and DeviceKit is no longer
  pulled in. Generated `userAgent` strings change accordingly:
  - `.default` / `.ios` / `.iphone` / `nil`: Mobile Safari on the current iOS,
    which WebKit reports with the frozen `iPhone OS 18_7` token.
  - `.android`: real Chrome for Android, i.e. the reduced
    `Linux; Android 10; K` token and the current `Chrome/<major>.0.0.0`
    (was a Pixel 7 with Chrome 123).
  - `.iosChrome`, `.desktop`, `.desktopFirefox`: current Chrome / Firefox
    versions with vendor-accurate reduced tokens.
  - `WebAuthViewController.usesBrowserUserAgent` reports the running device's
    real iOS version (`IOSDevice.current`), as before.
- The minimum deployment target is iOS 17.4.
- The TikTok web client (`TikTokWeb*`, `AccountType.tiktok`) was removed (#17).
- **`OAuth2Interceptor` now sends the access token in the `Authorization` header by default.**
  The default `tokenLocation` changed from `.params` to `.authorizationHeader`
  (RFC 6750 §2.1; query-string tokens leak into logs and caches). Every built-in
  provider already passes its location explicitly, so only custom interceptors
  created without `tokenLocation:` are affected. To keep the old behaviour, pass
  `tokenLocation: .params` (Foursquare's interceptor does).
- `AuthClient` only attaches credentials (bearer, DPoP, CSRF, OAuth 1.0a) to
  requests whose host is the host of `baseURLString`. Requests to absolute URLs on
  other hosts are sent unauthenticated and never trigger a token refresh. List
  extra hosts in `additionalAuthorizedHosts`. Subclasses that override
  `makeSessionManager(configuration:)` should compose
  `hostRestrictedRequestInterceptor` instead of `requestInterceptor`.
- AT Protocol OAuth callbacks must carry `iss`, and it must equal the
  authorization server's issuer exactly (RFC 9207). `state` is checked before an
  `error=` response is acted on.
- `APWebAuthSession.start()` throws if another `start()` is still pending.
  `WebTokenInterceptorViewController.start()` does the same, and calling it after
  the flow finished reports the original error instead of returning silently.
- TLS failures (`.secureConnectionFailed`, server certificate errors) are no
  longer classified as ignorable connection errors.

### Added

- **Bluesky / AT Protocol.** OAuth with PAR, PKCE and DPoP
  (`ATProtoOAuthClient`), `ATProtoAuthentication`, `ATProtoClient`,
  `BlueskyAPIClient` and `BlueskyUser`.
- **Mastodon.** `MastodonAuthentication` (persists the server host with the
  token), `MastodonAPIClient` (per-server base URL, host normalization,
  authorize URL), `MastodonUser` and `MastodonRelationship`.
- `WebAuthViewController`: `usesBrowserUserAgent` (present the web view as
  Mobile Safari; x.com's login link does nothing for the in-app user agent),
  links targeting a new window load in place, callback URLs are picked out of
  failed app-scheme redirects, and a `shouldReturnToAuthURL` hook bounces a
  flow back to the auth URL when login lands elsewhere (capped at three
  reloads).
- **OAuth 2.0 authorization code flow with PKCE.** `OAuth2AuthorizationCodeFlow`
  builds the authorization URL (`response_type=code`, random `state`, `S256`
  challenge), runs it in `ASWebAuthenticationSession` or `APWebAuthSession`,
  validates the redirect and `state` before reading `error=`, exchanges the
  code with `code_verifier` and `redirect_uri` using any
  `OAuth2ClientAuthentication` mode, and stores the tokens with
  `Auth2Authentication.applyTokenResponse(_:)`. Each step is also public for
  custom UI. Presets: `.x(...)`, `.gitHub(...)`, `.mastodon(host:...)`.
- `PKCE`: verifier generation and `S256` challenge (RFC 7636), now shared with
  the AT Protocol client (no behaviour change there).

- **Proactive OAuth 2.0 refresh.** `Auth2Authentication.expiresAt` records when
  the access token expires. It is set from `expires_in` on refresh, and on first
  login via the new `applyTokenResponse(_:)`. It is persisted in the Keychain
  blob; blobs saved by older versions still load, with `expiresAt` = `nil`.
  `OAuth2Interceptor` refreshes before sending a request when the token
  expires within `refreshLeeway` (default 60 s). Concurrent requests share one
  in-flight refresh, which the 401 retry path now uses too. On failure the
  current token is sent and proactive attempts pause for
  `proactiveRefreshBackoff` (default 30 s). The clock is injectable (`now:`).
- Token refresh responses accept `expires_in` as a number or a numeric string.
  A refresh response without `expires_in` clears `expiresAt` rather than
  keeping the old token's expiry.

- Token refresh for Reddit (`https://www.reddit.com/api/v1/access_token`),
  Pinterest v5 (`https://api.pinterest.com/v5/oauth/token`) and Twitch
  (`https://id.twitch.tv/oauth2/token`).
- `OAuth2ClientAuthentication.basicAuthorizationHeaderAllowingEmptySecret` for
  token endpoints that require HTTP Basic even from public clients (Reddit
  installed apps: `client_id:` with an empty password).
- `TransientNetworkRetrier` honours `Retry-After` (seconds or HTTP-date, capped).

### Fixed

- OAuth 2 refresh asks for JSON (`Accept: application/json`) and only wipes
  stored tokens on `invalid_grant`.
- `APWebAuthSession.start()` and `WebAuthViewController` resume the caller with
  `.canceled` when the controller is dismissed programmatically or released,
  and never resume it twice.
- OAuth 1.0a signatures no longer include URL fragment parameters, and a
  request without a usable base URI fails with `signatureGenerationFailed`
  instead of producing an invalid signature.
- AT Protocol entryway logins only store the DID document's handle after it
  resolves back to the same DID.
- `JSON.int32Number` no longer traps on values outside the `Int32` range.
- `TransientNetworkRetrier` no longer retries `501 Not Implemented`.

### Tests and CI

- WebTokenInterceptor and OAuth 1.0a signature vector tests, an iOS 17.4
  minimum-version simulator lane, and a SwiftLint lane (#22).
- Tests assert the APUserAgentGenerator 2.0 user agents for every browser mode.

## [2.0.0] - 2026-09-20

See the [GitHub release](https://github.com/aporat/APWebAuthentication/releases/tag/2.0.0).

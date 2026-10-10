# Changelog

## Unreleased

### Breaking changes

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

import Alamofire
import Foundation
@preconcurrency import SwiftyJSON

/// HTTP client for XRPC calls against an AT Protocol personal data server.
///
/// Requests are relative to `https://<pds>/xrpc/`; the PDS proxies AppView
/// lexicons such as `app.bsky.graph.getFollowers` and serves repository
/// writes such as `com.atproto.repo.createRecord` itself. Authentication is
/// handled by ``ATProtoInterceptor``.
///
/// **Example:**
/// ```swift
/// let client = ATProtoClient(accountType: AccountStore.bluesky, auth: auth)
/// let profile = try await client.request("app.bsky.actor.getProfile", parameters: ["actor": did])
/// ```
@MainActor
open class ATProtoClient: AuthClient {

    // MARK: - Properties

    public let auth: ATProtoAuthentication
    public let interceptor: ATProtoInterceptor
    public let oauthClient: ATProtoOAuthClient

    // MARK: - Rate Limits

    /// Requests left in the current window, from the last `RateLimit-Remaining`
    /// header seen. Bluesky's PDS sends the IETF draft headers on every response.
    public private(set) var rateLimitRemaining: Int?

    /// When the current window resets, from the last `RateLimit-Reset` header.
    public private(set) var rateLimitResetDate: Date?

    /// Records the rate-limit headers of a response. Called by the response
    /// monitor; exposed so tests can drive it directly.
    public func recordRateLimit(remaining: String?, reset: String?, receivedAt: Date = Date()) {
        if let remaining, let value = Int(remaining) {
            rateLimitRemaining = value
        }
        if let reset, let value = TimeInterval(reset) {
            rateLimitResetDate = Self.resetDate(from: value, receivedAt: receivedAt)
        }
    }

    /// The draft spec says seconds until reset; Bluesky sends a Unix
    /// timestamp. Anything past the year 2001 is treated as the latter.
    static func resetDate(from value: TimeInterval, receivedAt: Date) -> Date {
        value > 1_000_000_000 ? Date(timeIntervalSince1970: value) : receivedAt.addingTimeInterval(value)
    }

    // MARK: - Initialization

    public init(accountType: AccountType, auth: ATProtoAuthentication, oauthClient: ATProtoOAuthClient? = nil) {
        let oauthClient = oauthClient ?? ATProtoOAuthClient()
        self.auth = auth
        self.oauthClient = oauthClient
        self.interceptor = ATProtoInterceptor(auth: auth, oauthClient: oauthClient)
        super.init(
            accountType: accountType,
            baseURLString: Self.xrpcBaseURLString(for: auth.pdsURL),
            requestInterceptor: interceptor
        )
    }

    // MARK: - Base URL

    /// Points the client at the session's PDS. Call after login and after
    /// restoring a session, since the PDS is only known once the DID is.
    public func updateBaseURL() {
        baseURLString = Self.xrpcBaseURLString(for: auth.pdsURL)
    }

    static func xrpcBaseURLString(for pds: URL?) -> String {
        let host = pds ?? ATProtoOAuthClient.defaultAuthorizationServer
        return host.absoluteString.hasSuffix("/") ? host.absoluteString + "xrpc/" : host.absoluteString + "/xrpc/"
    }

    // MARK: - Record Timestamps

    /// `createdAt` for a new record: RFC 3339 in UTC with milliseconds, the
    /// form the lexicon `datetime` validator accepts (`2024-01-01T12:00:00.000Z`).
    public static func timestamp(_ date: Date = Date()) -> String {
        date.ISO8601Format(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    // MARK: - Session Configuration

    override open func makeSessionManager(configuration: URLSessionConfiguration) -> Session {
        let composed = Interceptor(
            retriers: [transientNetworkRetrier],
            interceptors: [requestInterceptor]
        )
        // Passing monitors replaces Alamofire's default list, and the
        // request logger listens to the notifications that default posts.
        return Session(
            configuration: configuration,
            delegate: SessionDelegate(),
            interceptor: composed,
            eventMonitors: [AlamofireNotifications(), ATProtoResponseMonitor(auth: auth, client: self)]
        )
    }

    // MARK: - Error Classification

    /// A 429 says when the window resets, which is worth more to the user
    /// than the server's terse message.
    override open func generateError(from response: DataResponse<JSON, AFError>) -> APWebAuthenticationError {
        guard response.response?.statusCodeValue == .tooManyRequests else {
            return super.generateError(from: response)
        }

        let json = parseJson(from: response)
        var reason = NSLocalizedString("Rate limit reached.", comment: "")
        if let header = response.response?.value(forHTTPHeaderField: "RateLimit-Reset"), let value = TimeInterval(header) {
            let resetDate = Self.resetDate(from: value, receivedAt: Date())
            let minutes = max(1, Int((resetDate.timeIntervalSinceNow / 60).rounded(.up)))
            reason = String(format: NSLocalizedString("Rate limit reached. Try again in %d min.", comment: ""), minutes)
        }
        return .rateLimit(reason: reason, responseJSON: json)
    }

    /// XRPC errors look like `{"error": "InvalidRequest", "message": "…"}`.
    override open func extractErrorMessage(from json: JSON?) -> String? {
        if let message = super.extractErrorMessage(from: json) {
            return message
        }
        return json?["error"].string
    }

    override open func isSessionExpiredError(response: DataResponse<JSON, AFError>, json: JSON?) -> Bool {
        guard response.response?.statusCodeValue == .unauthorized else { return false }
        // A nonce challenge is handled by the interceptor; if one still
        // surfaces here the retry budget ran out, so treat it as a failure
        // rather than logging the user out.
        let challenge = response.response?.value(forHTTPHeaderField: "WWW-Authenticate") ?? ""
        return !challenge.contains("use_dpop_nonce")
    }
}

// MARK: - Response Monitor

/// Captures the PDS's `DPoP-Nonce` and rate-limit headers from every
/// response, successful ones included, so the next proof is minted with a
/// current nonce and callers can pace themselves before a 429.
final class ATProtoResponseMonitor: EventMonitor, @unchecked Sendable {

    let queue = DispatchQueue(label: "com.apwebauthentication.atproto.responses")

    private let auth: ATProtoAuthentication
    private weak var client: ATProtoClient?

    init(auth: ATProtoAuthentication, client: ATProtoClient? = nil) {
        self.auth = auth
        self.client = client
    }

    func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: AFError?) {
        guard let response = task.response as? HTTPURLResponse else { return }

        let nonce = response.value(forHTTPHeaderField: "DPoP-Nonce")
        let remaining = response.value(forHTTPHeaderField: "RateLimit-Remaining")
        let reset = response.value(forHTTPHeaderField: "RateLimit-Reset")
        guard nonce != nil || remaining != nil || reset != nil else { return }

        Task { @MainActor in
            if let nonce, !nonce.isEmpty {
                self.auth.resourceServerNonce = nonce
            }
            self.client?.recordRateLimit(remaining: remaining, reset: reset)
        }
    }
}

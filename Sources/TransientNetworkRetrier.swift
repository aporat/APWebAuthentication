import Alamofire
import Foundation
import HTTPStatusCodes

/// Retries requests on transient network failures (timeouts, DNS, dropped
/// connections) and 500/502/503/504 responses, after a short delay — or after
/// the delay the server asks for in `Retry-After` (RFC 9110 §10.2.3), up to
/// ``maxRetryAfter``. `501 Not Implemented` is permanent and never retried.
///
/// Only idempotent methods are retried by default. A timeout or a 503 gives
/// no guarantee the server did *not* process the request, so replaying a
/// POST or PATCH could publish a post, follow a user, or send a message
/// twice. Callers that know a specific non-idempotent endpoint is safe to
/// replay (e.g. it carries an idempotency key) can widen `retryableMethods`.
public final class TransientNetworkRetrier: RequestRetrier, @unchecked Sendable {

    /// Methods RFC 9110 §9.2.2 defines as idempotent.
    public static let idempotentMethods: Set<HTTPMethod> = [
        .get, .head, .options, .trace, .put, .delete
    ]

    private let maxRetryCount: UInt

    /// Delay used when the response gives no `Retry-After`.
    public static let defaultRetryDelay: TimeInterval = 0.5

    /// Longest `Retry-After` the retrier will wait. A server asking for a
    /// longer pause gets no retry at all — retrying sooner than it asked
    /// would ignore the header, and waiting longer would hold the caller.
    public let maxRetryAfter: TimeInterval

    /// Status codes worth one more attempt. 501 is excluded: the server is
    /// saying it does not support the method, which a retry cannot change.
    private static let retryableStatusCodes: Set<Int> = [500, 502, 503, 504]

    /// HTTP methods eligible for automatic retry.
    public let retryableMethods: Set<HTTPMethod>

    private let lock = NSLock()
    private var _isReloadingCancelled = false

    /// Set to `true` to short-circuit any pending or future retry decisions.
    public var isReloadingCancelled: Bool {
        get { lock.withLock { _isReloadingCancelled } }
        set { lock.withLock { _isReloadingCancelled = newValue } }
    }

    private let transientURLErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .dnsLookupFailed,
        .notConnectedToInternet,
        .cannotFindHost,
        .networkConnectionLost
    ]

    /// - Parameters:
    ///   - maxRetryCount: How many times a single request may be retried.
    ///   - retryableMethods: Methods eligible for retry. Defaults to the
    ///     idempotent set; a request whose method is missing or not in this
    ///     set is never retried.
    ///   - maxRetryAfter: The longest `Retry-After` delay to honour, in seconds.
    public init(
        maxRetryCount: UInt = 1,
        retryableMethods: Set<HTTPMethod> = TransientNetworkRetrier.idempotentMethods,
        maxRetryAfter: TimeInterval = 10
    ) {
        self.maxRetryCount = maxRetryCount
        self.retryableMethods = retryableMethods
        self.maxRetryAfter = maxRetryAfter
    }

    public func retry(_ request: Request, for session: Session, dueTo error: any Error, completion: @escaping (RetryResult) -> Void) {
        guard request.retryCount < maxRetryCount,
              !isReloadingCancelled,
              let method = request.request?.method,
              retryableMethods.contains(method) else {
            completion(.doNotRetry)
            return
        }

        guard shouldRetryRequest(error, request: request) else {
            completion(.doNotRetry)
            return
        }

        // A short default delay keeps the overall failure window inside the
        // resource timeout so users get a prompt error; a server that names
        // its own delay gets it, within `maxRetryAfter`.
        guard let retryAfter = request.response?.value(forHTTPHeaderField: "Retry-After") else {
            completion(.retryWithDelay(Self.defaultRetryDelay))
            return
        }
        guard let delay = Self.retryAfterDelay(retryAfter) else {
            completion(.retryWithDelay(Self.defaultRetryDelay))
            return
        }
        if delay > maxRetryAfter {
            completion(.doNotRetry)
        } else {
            completion(.retryWithDelay(delay))
        }
    }

    // MARK: - Retry-After

    /// Parses a `Retry-After` value — delay-seconds or an HTTP-date
    /// (RFC 9110 §10.2.3) — into a non-negative delay from `now`.
    /// Returns `nil` for values that are neither.
    static func retryAfterDelay(_ value: String, now: Date = Date()) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed.allSatisfy(\.isASCIIDigit) {
            // Saturate absurdly long digit strings instead of failing to parse.
            return TimeInterval(trimmed) ?? .greatestFiniteMagnitude
        }
        guard let date = httpDate(from: trimmed) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }

    /// IMF-fixdate plus the two obsolete forms recipients must accept
    /// (RFC 9110 §5.6.7).
    private static let httpDateFormats = [
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEEE, dd-MMM-yy HH:mm:ss zzz",
        "EEE MMM d HH:mm:ss yyyy"
    ]

    private static func httpDate(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        for format in httpDateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private func shouldRetryRequest(_ error: (any Error)?, request: Request?) -> Bool {
        if isReloadingCancelled { return false }

        if let urlErr = extractURLError(from: error), transientURLErrorCodes.contains(urlErr.code) {
            return true
        }

        if let nsError = error as? NSError, nsError.domain == NSPOSIXErrorDomain, nsError.code == 53 {
            return true
        }

        if let status = request?.response?.statusCode, Self.retryableStatusCodes.contains(status) {
            return true
        }

        return false
    }

    private func extractURLError(from error: (any Error)?) -> URLError? {
        if let urlError = error as? URLError { return urlError }

        if let afError = error as? AFError {
            if case let .sessionTaskFailed(underlyingError) = afError, let urlError = underlyingError as? URLError {
                return urlError
            }
            if let urlError = afError.underlyingError as? URLError {
                return urlError
            }
        }
        return nil
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}

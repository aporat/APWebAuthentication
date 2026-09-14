import Alamofire
import Foundation
import HTTPStatusCodes

/// Retries requests on transient network failures (timeouts, DNS, dropped
/// connections) and 5xx responses, after a short fixed delay.
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
    public init(
        maxRetryCount: UInt = 1,
        retryableMethods: Set<HTTPMethod> = TransientNetworkRetrier.idempotentMethods
    ) {
        self.maxRetryCount = maxRetryCount
        self.retryableMethods = retryableMethods
    }

    public func retry(_ request: Request, for session: Session, dueTo error: any Error, completion: @escaping (RetryResult) -> Void) {
        guard request.retryCount < maxRetryCount,
              !isReloadingCancelled,
              let method = request.request?.method,
              retryableMethods.contains(method) else {
            completion(.doNotRetry)
            return
        }

        if shouldRetryRequest(error, request: request) {
            // Single 0.5s delay before the one retry — keeps the overall failure window
            // inside the resource timeout so users get a prompt error.
            completion(.retryWithDelay(0.5))
        } else {
            completion(.doNotRetry)
        }
    }

    private func shouldRetryRequest(_ error: (any Error)?, request: Request?) -> Bool {
        if isReloadingCancelled { return false }

        if let urlErr = extractURLError(from: error), transientURLErrorCodes.contains(urlErr.code) {
            return true
        }

        if let nsError = error as? NSError, nsError.domain == NSPOSIXErrorDomain, nsError.code == 53 {
            return true
        }

        if let status = request?.response?.statusCode, (500...504).contains(status) {
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

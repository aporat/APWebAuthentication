import Alamofire
import Foundation
import HTTPStatusCodes

/// Retries requests on transient network failures (timeouts, DNS, dropped
/// connections) and 5xx responses. Uses exponential backoff so retries span
/// real-world network handoffs (e.g. WiFi ↔ cellular).
public final class TransientNetworkRetrier: RequestRetrier, @unchecked Sendable {

    private let maxRetryCount: UInt
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

    public init(maxRetryCount: UInt = 1) {
        self.maxRetryCount = maxRetryCount
    }

    public func retry(_ request: Request, for session: Session, dueTo error: any Error, completion: @escaping (RetryResult) -> Void) {
        guard request.retryCount < maxRetryCount, !isReloadingCancelled else {
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

import Alamofire
import Foundation

/// The hosts an ``AuthClient`` may send credentials to.
///
/// Thread-safe, because Alamofire consults it from its own queues while the
/// client (which is main-actor isolated) updates it when its base URL changes.
public final class AuthorizedHosts: @unchecked Sendable {

    private let lock = NSLock()
    private var hosts: Set<String>

    public init(_ hosts: Set<String> = []) {
        self.hosts = Set(hosts.map { $0.lowercased() })
    }

    /// The current host set (lower-cased).
    public var current: Set<String> {
        lock.withLock { hosts }
    }

    func replace(with hosts: Set<String>) {
        let normalized = Set(hosts.map { $0.lowercased() })
        lock.withLock { self.hosts = normalized }
    }

    /// Whether `url` points at one of the authorized hosts.
    public func allows(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased(), !host.isEmpty else { return false }
        return current.contains(host)
    }
}

/// Wraps a credential-attaching interceptor so it only runs for requests to
/// the client's own hosts.
///
/// `AuthClient.url(for:)` passes absolute URLs through untouched, so without
/// this a request to any other host (a CDN, a link from an API response, a
/// third-party service) would carry the user's bearer token, DPoP proof or
/// CSRF header. Requests to other hosts go out unadapted, and their failures
/// never trigger the wrapped interceptor's retry (token refresh, DPoP nonce).
struct HostRestrictedInterceptor: RequestInterceptor {

    let wrapped: any RequestInterceptor
    let hosts: AuthorizedHosts

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        guard hosts.allows(urlRequest.url) else {
            completion(.success(urlRequest))
            return
        }
        wrapped.adapt(urlRequest, for: session, completion: completion)
    }

    func adapt(_ urlRequest: URLRequest, using state: RequestAdapterState, completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void) {
        guard hosts.allows(urlRequest.url) else {
            completion(.success(urlRequest))
            return
        }
        wrapped.adapt(urlRequest, using: state, completion: completion)
    }

    func retry(_ request: Request, for session: Session, dueTo error: any Error, completion: @escaping @Sendable (RetryResult) -> Void) {
        guard hosts.allows(request.request?.url ?? request.firstRequest?.url) else {
            completion(.doNotRetry)
            return
        }
        wrapped.retry(request, for: session, dueTo: error, completion: completion)
    }
}

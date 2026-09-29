import Alamofire
import Foundation

/// Signs XRPC requests with the session's DPoP-bound access token and keeps
/// the session alive.
///
/// On each request it adds `Authorization: DPoP <token>` and a `DPoP` proof
/// that binds the token hash (`ath`) and the PDS's latest nonce. Two kinds of
/// 401 are retried: a `use_dpop_nonce` challenge (once, with the nonce from
/// the response) and an expired token (once, after a refresh). Concurrent
/// requests share a single in-flight refresh.
public final class ATProtoInterceptor: RequestInterceptor, @unchecked Sendable {

    // MARK: - Properties

    let auth: ATProtoAuthentication
    let oauthClient: ATProtoOAuthClient

    @MainActor private var refreshTask: Task<Bool, Never>?

    private let lock = NSLock()
    private var nonceRetriedRequestIDs: [UUID] = []
    private var refreshRetriedRequestIDs: [UUID] = []
    private static let retriedRequestIDsLimit = 64

    // MARK: - Initialization

    public init(auth: ATProtoAuthentication, oauthClient: ATProtoOAuthClient) {
        self.auth = auth
        self.oauthClient = oauthClient
    }

    // MARK: - RequestAdapter

    public func adapt(
        _ urlRequest: URLRequest,
        for _: Session,
        completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
    ) {
        Task { @MainActor in
            var urlRequest = urlRequest

            if let userAgent = auth.userAgent, !userAgent.isEmpty {
                urlRequest.headers.add(.userAgent(userAgent))
            }
            urlRequest.headers.add(.accept("application/json"))

            // Refresh ahead of time rather than burning a round trip on a 401.
            if auth.isAccessTokenExpired, auth.refreshToken != nil {
                _ = await refreshAccessToken()
            }

            guard let accessToken = auth.accessToken, !accessToken.isEmpty,
                  let key = auth.dpopKey,
                  let url = urlRequest.url else {
                completion(.success(urlRequest))
                return
            }

            do {
                let proof = try key.proof(
                    method: urlRequest.httpMethod ?? "GET",
                    url: url,
                    nonce: auth.resourceServerNonce,
                    accessToken: accessToken
                )
                urlRequest.headers.add(.authorization("DPoP \(accessToken)"))
                urlRequest.headers.add(name: "DPoP", value: proof)
                completion(.success(urlRequest))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - RequestRetrier

    public func retry(
        _ request: Request,
        for _: Session,
        dueTo _: Error,
        completion: @escaping @Sendable (RetryResult) -> Void
    ) {
        guard let response = request.task?.response as? HTTPURLResponse,
              response.statusCode == 401 else {
            completion(.doNotRetry)
            return
        }

        let challenge = response.value(forHTTPHeaderField: "WWW-Authenticate") ?? ""
        let nonce = response.value(forHTTPHeaderField: "DPoP-Nonce")

        if challenge.contains("use_dpop_nonce"), let nonce, !nonce.isEmpty {
            guard claim(request.id, in: &nonceRetriedRequestIDs) else {
                completion(.doNotRetry)
                return
            }
            Task { @MainActor in
                self.auth.resourceServerNonce = nonce
                completion(.retry)
            }
            return
        }

        guard claim(request.id, in: &refreshRetriedRequestIDs) else {
            completion(.doNotRetry)
            return
        }

        Task { @MainActor in
            if let nonce, !nonce.isEmpty {
                self.auth.resourceServerNonce = nonce
            }
            let refreshed = await self.refreshAccessToken()
            completion(refreshed ? .retry : .doNotRetry)
        }
    }

    /// Records that `id` has used its one retry of this kind. Returns false
    /// when it already had.
    private func claim(_ id: UUID, in list: inout [UUID]) -> Bool {
        lock.withLock {
            guard !list.contains(id) else { return false }
            list.append(id)
            if list.count > Self.retriedRequestIDsLimit {
                list.removeFirst()
            }
            return true
        }
    }

    // MARK: - Token Refresh

    /// Refreshes the session, coalescing concurrent callers onto one request.
    @MainActor
    public func refreshAccessToken() async -> Bool {
        if let task = refreshTask {
            return await task.value
        }

        let task = Task<Bool, Never> { @MainActor in
            do {
                try await oauthClient.refresh(auth: auth)
                await auth.save()
                return true
            } catch {
                // Only a definitive rejection ends the session; a flaky
                // network must not log the user out.
                if case APWebAuthenticationError.sessionExpired = error {
                    Log.atproto.error("Refresh token rejected; clearing session")
                    auth.invalidateTokens()
                    await auth.save()
                } else {
                    Log.atproto.error("Token refresh failed: \(error.localizedDescription, privacy: .public)")
                }
                return false
            }
        }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result
    }
}

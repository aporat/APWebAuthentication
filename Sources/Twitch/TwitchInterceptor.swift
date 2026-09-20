import Alamofire
import Foundation

// MARK: - TwitchInterceptor

public final class TwitchInterceptor: OAuth2Interceptor, @unchecked Sendable {

    // MARK: - Request Adaptation

    override public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
    ) {
        // Hop to MainActor once instead of awaiting each `auth` property
        // independently — every separate `await` is another suspension the
        // auth state can change across, which would let one request go out
        // carrying a mix of old and new credentials.
        Task { @MainActor in
            var urlRequest = urlRequest

            // Twitch Helix API requires the Client-ID header for all requests
            if let clientId = self.auth.clientId {
                urlRequest.headers.add(HTTPHeader(name: "Client-ID", value: clientId))
            }

            // Call super to add OAuth token
            super.adapt(urlRequest, for: session, completion: completion)
        }
    }
}

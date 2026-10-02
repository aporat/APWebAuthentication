import Alamofire
import Foundation

// MARK: - MastodonAPIClient

/// HTTP client for the Mastodon REST API (`/api/v1`) of one server.
///
/// The base URL follows ``MastodonAuthentication/instanceHost``; call
/// ``updateBaseURL()`` after the host changes (login, or loading a saved
/// session) so requests go to the right server.
///
/// Also works against servers that implement the Mastodon API, such as
/// Pixelfed, Akkoma and GoToSocial.
@MainActor
public final class MastodonAPIClient: OAuth2Client {

    // MARK: - Constants

    /// Scopes a follower analytics client needs: the signed-in profile,
    /// the follower and following lists plus relationships, and follow /
    /// unfollow.
    nonisolated public static let defaultScope = "read:accounts read:follows write:follows"

    /// The server's hard cap on `limit` for the account list endpoints.
    nonisolated public static let maxUsersPerPage = 80

    /// Where requests go before a host is known. Requests to it fail at the
    /// network layer rather than hitting a real server.
    nonisolated private static let placeholderBaseURL = "https://mastodon.invalid/api/v1/"

    // MARK: - Properties

    public let auth: MastodonAuthentication

    // MARK: - Initialization

    /// Creates a client for the server named by `auth.instanceHost`.
    ///
    /// - Parameter auth: The account credentials, including the server host
    public init(auth: MastodonAuthentication) {
        self.auth = auth
        let interceptor = OAuth2Interceptor(auth: auth, tokenLocation: .authorizationHeader)
        super.init(
            accountType: AccountStore.mastodon,
            baseURLString: Self.apiBaseURLString(host: auth.instanceHost),
            requestInterceptor: interceptor
        )
    }

    // MARK: - Base URL

    /// Points the client at `auth.instanceHost`.
    public func updateBaseURL() {
        baseURLString = Self.apiBaseURLString(host: auth.instanceHost)
    }

    nonisolated static func apiBaseURLString(host: String?) -> String {
        guard let host, !host.isEmpty else { return placeholderBaseURL }
        return "https://\(host)/api/v1/"
    }

    // MARK: - Hosts

    /// Turns whatever the user typed into a bare hostname, or nil when it
    /// cannot be one.
    ///
    /// Accepts `mastodon.social`, `https://mastodon.social/`, a profile URL
    /// like `https://mastodon.social/@alice`, and a full handle such as
    /// `alice@mastodon.social` or `@alice@mastodon.social`.
    nonisolated public static func normalizedHost(from input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return nil }

        if text.contains("://") {
            // A URL: keep the host. Checked first because a profile URL
            // (`https://host/@alice`) also contains an "@".
            guard let url = URL(string: text), let host = url.host else { return nil }
            text = host
        } else {
            // A bare host with a path (`host/@alice`): drop the path.
            if let slash = text.firstIndex(of: "/") {
                text = String(text[..<slash])
            }
            // A handle: keep what follows the last "@".
            if text.contains("@") {
                let parts = text.split(separator: "@", omittingEmptySubsequences: true)
                guard let last = parts.last else { return nil }
                text = String(last)
            }
        }

        // Strip a port or trailing dot; neither belongs in a server name here.
        if let colon = text.firstIndex(of: ":") {
            text = String(text[..<colon])
        }
        while text.hasSuffix(".") {
            text.removeLast()
        }

        guard isValidHost(text) else { return nil }
        return text
    }

    /// A host is at least two non-empty labels of letters, digits and
    /// hyphens, so `localhost` and bare words are rejected.
    nonisolated private static func isValidHost(_ host: String) -> Bool {
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        for label in labels {
            guard !label.isEmpty, !label.hasPrefix("-"), !label.hasSuffix("-"),
                  label.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
                return false
            }
        }
        return true
    }

    // MARK: - OAuth

    /// The authorization code URL on `host` for the given client.
    ///
    /// - Parameters:
    ///   - host: The server to sign in on
    ///   - clientId: The client id registered on that server
    ///   - redirectURL: A redirect URI registered with that client, verbatim
    ///   - scope: Space-separated scopes to request
    ///   - state: Opaque value the server echoes back on the redirect
    nonisolated public static func authorizationURL(
        host: String,
        clientId: String,
        redirectURL: String,
        scope: String = defaultScope,
        state: String? = nil
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/oauth/authorize"

        var items = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURL),
            URLQueryItem(name: "scope", value: scope)
        ]
        if let state, !state.isEmpty {
            items.append(URLQueryItem(name: "state", value: state))
        }
        components.queryItems = items

        return components.url
    }

    /// The web profile for an account on `host`, e.g. `https://mastodon.social/@alice`.
    /// For a remote account (`alice@other.social`) this is the local copy on
    /// `host`, which is what the signed-in user can act on.
    nonisolated public static func profileURL(host: String, acct: String) -> URL? {
        let handle = acct.hasPrefix("@") ? String(acct.dropFirst()) : acct
        guard !handle.isEmpty else { return nil }
        return URL(string: "https://\(host)/@\(handle)")
    }
}

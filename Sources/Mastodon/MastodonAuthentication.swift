import Foundation
@preconcurrency import SwiftyJSON

// MARK: - MastodonAuthentication

/// OAuth 2.0 credentials for a Mastodon account.
///
/// Mastodon is federated: every server is its own OAuth provider and its own
/// API host, so alongside the usual token this also remembers which server
/// issued it. Without the host the token is useless, which is why it is
/// persisted with the credentials rather than kept on the provider.
///
/// Mastodon access tokens do not expire, so there is no refresh flow.
@MainActor
public final class MastodonAuthentication: Auth2Authentication {

    // MARK: - Settings Storage

    private struct AuthSettings: Codable, Sendable {
        let accessToken: String?
        let refreshToken: String?
        let clientId: String?
        let clientSecret: String?
        let instanceHost: String?
    }

    // MARK: - Instance

    /// Hostname of the server the account lives on, e.g. `mastodon.social`.
    /// Always a bare host: no scheme, path, or trailing slash.
    public var instanceHost: String?

    /// Origin of the account's server, or nil until a host is known.
    public var instanceURL: URL? {
        guard let instanceHost, !instanceHost.isEmpty else { return nil }
        return URL(string: "https://\(instanceHost)")
    }

    // MARK: - Authorization Status

    override public var isAuthorized: Bool {
        super.isAuthorized && instanceURL != nil
    }

    // MARK: - Persistence

    override public var keychainCategory: String { "mastodon" }

    override public func save() async {
        let settings = AuthSettings(
            accessToken: accessToken,
            refreshToken: refreshToken,
            clientId: clientId,
            clientSecret: clientSecret,
            instanceHost: instanceHost
        )
        await saveSettings(settings)
    }

    override public func load() async {
        guard let settings = await loadSettings(AuthSettings.self) else { return }
        accessToken = settings.accessToken
        refreshToken = settings.refreshToken
        clientId = settings.clientId
        clientSecret = settings.clientSecret
        instanceHost = settings.instanceHost
    }

    override public func delete() async {
        await super.delete()
        instanceHost = nil
    }

    // MARK: - Runtime Configuration

    /// Supported options, on top of ``Auth2Authentication/configure(with:)``:
    /// - `host`: the server the login is for (normalized through
    ///   ``MastodonAPIClient/normalizedHost(from:)``)
    override public func configure(with options: JSON?) {
        super.configure(with: options)

        if let value = options?["host"].string,
           let host = MastodonAPIClient.normalizedHost(from: value) {
            instanceHost = host
        }
    }
}

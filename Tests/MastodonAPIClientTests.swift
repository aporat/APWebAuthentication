@testable import APWebAuthentication
import XCTest

final class MastodonAPIClientTests: XCTestCase {

    // MARK: - Host Normalization

    func testNormalizedHost_acceptsBareHost() {
        XCTAssertEqual(MastodonAPIClient.normalizedHost(from: "mastodon.social"), "mastodon.social")
        XCTAssertEqual(MastodonAPIClient.normalizedHost(from: "  Fosstodon.ORG \n"), "fosstodon.org")
        XCTAssertEqual(MastodonAPIClient.normalizedHost(from: "social.example.co.uk."), "social.example.co.uk")
    }

    func testNormalizedHost_acceptsURLs() {
        XCTAssertEqual(MastodonAPIClient.normalizedHost(from: "https://mastodon.social"), "mastodon.social")
        XCTAssertEqual(MastodonAPIClient.normalizedHost(from: "https://mastodon.social/"), "mastodon.social")
        XCTAssertEqual(MastodonAPIClient.normalizedHost(from: "https://mastodon.social/@alice"), "mastodon.social")
        XCTAssertEqual(MastodonAPIClient.normalizedHost(from: "mastodon.social/explore"), "mastodon.social")
        XCTAssertEqual(MastodonAPIClient.normalizedHost(from: "mastodon.social/@alice"), "mastodon.social")
        XCTAssertEqual(MastodonAPIClient.normalizedHost(from: "mastodon.social:443"), "mastodon.social")
    }

    func testNormalizedHost_acceptsHandles() {
        XCTAssertEqual(MastodonAPIClient.normalizedHost(from: "alice@mastodon.social"), "mastodon.social")
        XCTAssertEqual(MastodonAPIClient.normalizedHost(from: "@alice@mastodon.social"), "mastodon.social")
    }

    func testNormalizedHost_rejectsInvalidInput() {
        XCTAssertNil(MastodonAPIClient.normalizedHost(from: ""))
        XCTAssertNil(MastodonAPIClient.normalizedHost(from: "   "))
        XCTAssertNil(MastodonAPIClient.normalizedHost(from: "localhost"))
        XCTAssertNil(MastodonAPIClient.normalizedHost(from: "alice"))
        XCTAssertNil(MastodonAPIClient.normalizedHost(from: "@alice"))
        XCTAssertNil(MastodonAPIClient.normalizedHost(from: "mastodon social"))
        XCTAssertNil(MastodonAPIClient.normalizedHost(from: "-bad.example"))
        XCTAssertNil(MastodonAPIClient.normalizedHost(from: "bad..example"))
    }

    // MARK: - Authorization URL

    func testAuthorizationURL_includesEveryParameter() throws {
        let url = try XCTUnwrap(MastodonAPIClient.authorizationURL(
            host: "mastodon.social",
            clientId: "abc123",
            redirectURL: "https://api.example.com/oauth/mastodon",
            state: "xyz"
        ))

        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "mastodon.social")
        XCTAssertEqual(components.path, "/oauth/authorize")

        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
        XCTAssertEqual(query["response_type"], "code")
        XCTAssertEqual(query["client_id"], "abc123")
        XCTAssertEqual(query["redirect_uri"], "https://api.example.com/oauth/mastodon")
        XCTAssertEqual(query["scope"], MastodonAPIClient.defaultScope)
        XCTAssertEqual(query["state"], "xyz")
    }

    func testAuthorizationURL_omitsEmptyState() throws {
        let url = try XCTUnwrap(MastodonAPIClient.authorizationURL(host: "mastodon.social", clientId: "abc", redirectURL: "https://example.com/cb", state: ""))
        let names = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.map(\.name) ?? []
        XCTAssertFalse(names.contains("state"))
    }

    // MARK: - Profile URL

    func testProfileURL() {
        XCTAssertEqual(MastodonAPIClient.profileURL(host: "mastodon.social", acct: "alice")?.absoluteString, "https://mastodon.social/@alice")
        XCTAssertEqual(MastodonAPIClient.profileURL(host: "mastodon.social", acct: "@bob@fosstodon.org")?.absoluteString, "https://mastodon.social/@bob@fosstodon.org")
        XCTAssertNil(MastodonAPIClient.profileURL(host: "mastodon.social", acct: "@"))
    }

    // MARK: - Base URL

    @MainActor
    func testBaseURL_followsInstanceHost() {
        let auth = MastodonAuthentication()
        let client = MastodonAPIClient(auth: auth)
        XCTAssertEqual(client.baseURLString, "https://mastodon.invalid/api/v1/")

        auth.instanceHost = "fosstodon.org"
        client.updateBaseURL()
        XCTAssertEqual(client.baseURLString, "https://fosstodon.org/api/v1/")
    }
}

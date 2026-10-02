@testable import APWebAuthentication
import XCTest

@MainActor
final class AccountStoreTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        AccountStore.disableAll()
    }
    
    override func tearDown() async throws {
        AccountStore.disableAll()
        try await super.tearDown()
    }

    func testAccountTypes_emptyDefaults_returnsEmpty() {
        let accounts = AccountStore.accountTypes
        XCTAssertTrue(accounts.isEmpty)
    }

    func testAccountTypes_withEnabledServices_returnsCorrectTypes() {
        AccountStore.setEnabled(AccountType.Code.x, enabled: true)
        AccountStore.setEnabled(AccountType.Code.github, enabled: true)

        let accounts = AccountStore.accountTypes
        let codes = accounts.map { $0.code }

        XCTAssertTrue(codes.contains(.x))
        XCTAssertTrue(codes.contains(.github))
        XCTAssertEqual(accounts.count, 2)
    }
}

// MARK: - Bluesky

@MainActor
final class BlueskyAccountTypeTests: XCTestCase {

    func testBluesky_isRegistered() {
        XCTAssertEqual(AccountStore.bluesky.code, .bluesky)
        XCTAssertEqual(AccountStore.bluesky.code.rawValue, "com.apple.bluesky")
        XCTAssertEqual(AccountStore.bluesky.code.platformName, "Bluesky")
        XCTAssertEqual(AccountStore.bluesky.webAddress, "bsky.app")
        XCTAssertTrue(AccountStore.all.contains(AccountStore.bluesky))
        XCTAssertEqual(AccountStore.accountType(for: .bluesky), AccountStore.bluesky)
    }
}

// MARK: - Mastodon

@MainActor
final class MastodonAccountTypeTests: XCTestCase {

    func testMastodon_isRegistered() {
        XCTAssertEqual(AccountStore.mastodon.code, .mastodon)
        XCTAssertEqual(AccountStore.mastodon.code.rawValue, "com.apple.mastodon")
        XCTAssertEqual(AccountStore.mastodon.code.platformName, "Mastodon")
        XCTAssertEqual(AccountStore.mastodon.webAddress, "mastodon.social")
        XCTAssertTrue(AccountStore.all.contains(AccountStore.mastodon))
        XCTAssertEqual(AccountStore.accountType(for: .mastodon), AccountStore.mastodon)
    }
}

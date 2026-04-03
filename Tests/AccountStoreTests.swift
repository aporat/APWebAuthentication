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

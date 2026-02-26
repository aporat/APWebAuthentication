@testable import APWebAuthentication
import XCTest

@MainActor
final class AccountStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Defaults.removeAll()
        AccountStore.disableAll()
    }
    
    override func tearDown() {
        AccountStore.disableAll()
        super.tearDown()
    }

    func testAccountTypes_emptyDefaults_returnsEmpty() {
        let accounts = AccountStore.accountTypes
        XCTAssertTrue(accounts.isEmpty)
    }

    func testAccountTypes_withEnabledServices_returnsCorrectTypes() {
        AccountStore.setEnabled(AccountType.Code.twitter, enabled: true)
        AccountStore.setEnabled(AccountType.Code.github, enabled: true)

        let accounts = AccountStore.accountTypes
        let codes = accounts.map { $0.code }

        XCTAssertTrue(codes.contains(.twitter))
        XCTAssertTrue(codes.contains(.github))
        XCTAssertEqual(accounts.count, 2)
    }
}

@testable import APWebAuthentication
@preconcurrency import SwiftyUserDefaults
import XCTest

@MainActor
final class AccountStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Defaults.removeAll()
    }

    func testAccountTypes_emptyDefaults_returnsEmpty() {
        let accounts = AccountStore.accountTypes
        XCTAssertTrue(accounts.isEmpty)
    }

    func testAccountTypes_withEnabledServices_returnsCorrectTypes() {
        Defaults[\.Twitter] = true
        Defaults[\.Github] = true

        let accounts = AccountStore.accountTypes
        let codes = accounts.map { $0.code }

        XCTAssertTrue(codes.contains(.twitter))
        XCTAssertTrue(codes.contains(.github))
        XCTAssertEqual(accounts.count, 2)
    }
}

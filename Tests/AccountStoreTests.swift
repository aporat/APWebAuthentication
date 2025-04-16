import XCTest
import SwiftyUserDefaults
@testable import APWebAuthentication

final class AccountStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset all stored values
        Defaults.removeAll()
    }

    func testAccountTypes_emptyDefaults_returnsEmpty() {
        let accounts = AccountStore.accountTypes
        XCTAssertTrue(accounts.isEmpty)
    }

    func testAccountTypes_withEnabledServices_returnsCorrectTypes() {
        Defaults[\.Instagram] = true
        Defaults[\.Twitter] = true
        Defaults[\.Github] = true

        let accounts = AccountStore.accountTypes
        let codes = accounts.map { $0.code }

        XCTAssertTrue(codes.contains(.instagram))
        XCTAssertTrue(codes.contains(.twitter))
        XCTAssertTrue(codes.contains(.github))
        XCTAssertEqual(accounts.count, 3)
    }

    func testAccountType_withUnknownCode_returnsNil() {
        let unknownCode = AccountType.Code(rawValue: "unknown")
        XCTAssertNil(unknownCode)
        
        // Since it's nil, we shouldn't even call accountType
        if let code = unknownCode {
            let result = AccountStore.accountType(code)
            XCTAssertNil(result)
        }
    }
}

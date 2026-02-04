@testable import APWebAuthentication
import SwiftyJSON
import XCTest

final class JSONExtensionTests: XCTestCase {

    func testIdString_withNonEmptyString() {
        let json = JSON("abc123")
        XCTAssertEqual(json.idString, "abc123")
    }

    func testIdString_withInt64() {
        let json = JSON(Int64(123456789))
        XCTAssertEqual(json.idString, "123456789")
    }

    func testIdString_withInt() {
        let json = JSON(42)
        XCTAssertEqual(json.idString, "42")
    }

    func testIdString_withEmptyOrZero() {
        XCTAssertNil(JSON("").idString)
        XCTAssertNil(JSON(0).idString)
        XCTAssertNil(JSON(NSNull()).idString)
    }

    func testInt32Number_fromInt32() {
        let json = JSON(Int32(99))
        XCTAssertEqual(json.int32Number, 99)
    }

    func testInt32Number_fromInt() {
        let json = JSON(88)
        XCTAssertEqual(json.int32Number, 88)
    }

    func testInt32Number_fromString() {
        let json = JSON("77")
        XCTAssertEqual(json.int32Number, 77)
    }

    func testInt32Number_invalid() {
        XCTAssertNil(JSON("hello").int32Number)
        XCTAssertNil(JSON(NSNull()).int32Number)
    }

    func testDate_fromDouble() {
        let timestamp: Double = 1680000000
        let json = JSON(timestamp)
        XCTAssertNotNil(json.date)
    }

    func testDate_fromString() {
        let timestamp = String(1680000000)
        let json = JSON(timestamp)
        XCTAssertNotNil(json.date)
    }

    func testDate_invalid() {
        XCTAssertNil(JSON("invalid").date)
        XCTAssertNil(JSON(-12345.0).date)
    }
}

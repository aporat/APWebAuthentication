import XCTest
import SwiftyJSON
@testable import APWebAuthentication

final class FoursquareUserTests: XCTestCase {
    func testFoursquareUserInit() {
        let json = JSON([
            "id": "123456",
            "homeCity": "NYC",
            "firstName": "John",
            "lastName": "Doe",
            "photo": [
                "prefix": "https://foursquare.com/img/",
                "suffix": "/avatar.jpg"
            ]
        ])

        let user = FoursquareUser(info: json)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.userId, "123456")
        XCTAssertEqual(user?.username, "NYC")
        XCTAssertEqual(user?.fullname, "John Doe")
        XCTAssertEqual(user?.avatarPicture?.absoluteString, "https://foursquare.com/img/110x110/avatar.jpg")
    }
}

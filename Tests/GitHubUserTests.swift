import XCTest
import SwiftyJSON
@testable import APWebAuthentication

final class GitHubUserTests: XCTestCase {
    func testGitHubUserInit() {
        let json = JSON([
            "id": "7890",
            "login": "octocat",
            "name": "The Octocat",
            "avatar_url": "https://github.com/images/octocat.png"
        ])

        let user = GitHubUser(info: json)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.userId, "7890")
        XCTAssertEqual(user?.username, "octocat")
        XCTAssertEqual(user?.fullname, "The Octocat")
        XCTAssertEqual(user?.avatarPicture?.absoluteString, "https://github.com/images/octocat.png")
    }
}

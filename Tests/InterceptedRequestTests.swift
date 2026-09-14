@testable import APWebAuthentication
import XCTest

final class InterceptedRequestTests: XCTestCase {

    func testResponseHeaders_parseCRLFAndColonsInValues() {
        let raw = "content-type: application/json; charset=utf-8\r\n"
            + "date: Tue, 02 Jan 2024 10:11:12 GMT\r\n"
            + "link: <https://api.example.com/items?page=2>; rel=\"next\"\r\n"
            + "x-empty:\r\n"

        let headers = InterceptedRequest.parseResponseHeaders(raw)

        XCTAssertEqual(headers["content-type"], "application/json; charset=utf-8")
        XCTAssertEqual(headers["date"], "Tue, 02 Jan 2024 10:11:12 GMT")
        XCTAssertEqual(headers["link"], "<https://api.example.com/items?page=2>; rel=\"next\"")
        XCTAssertEqual(headers["x-empty"], "")
        XCTAssertEqual(headers.count, 4)
    }

    func testResponseHeaders_nilOrBlankInput() {
        XCTAssertEqual(InterceptedRequest.parseResponseHeaders(nil), [:])
        XCTAssertEqual(InterceptedRequest.parseResponseHeaders(""), [:])
        XCTAssertEqual(InterceptedRequest.parseResponseHeaders("\r\n\r\n"), [:])
    }

    func testInit_populatesBothHeaderSets() {
        let request = InterceptedRequest(
            responseURL: URL(string: "https://example.com/api")!,
            targetURL: nil,
            requestHeaders: ["x-csrf": "abc", "count": 3],
            responseHeaders: "set-cookie: a=b\r\n",
            statusCode: 200
        )

        XCTAssertEqual(request.requestHeaders, ["x-csrf": "abc", "count": "3"])
        XCTAssertEqual(request.responseHeaders, ["set-cookie": "a=b"])
        XCTAssertEqual(request.statusCode, 200)
    }
}

import XCTest
@testable import APWebAuthentication

final class APWebAuthenticationLinkTests: XCTestCase {

    func testInitWithURIAndParameters() {
        let link = APWebAuthenticationLink(uri: "https://example.com", parameters: ["rel": "next"])
        XCTAssertEqual(link.uri, "https://example.com")
        XCTAssertEqual(link.parameters["rel"], "next")
        XCTAssertEqual(link.relationType, "next")
    }

    func testHTMLRendering() {
        let link = APWebAuthenticationLink(uri: "https://example.com", parameters: ["rel": "next", "type": "text/html"])
        let html = link.html
        XCTAssertTrue(html.contains("rel=\"next\""))
        XCTAssertTrue(html.contains("type=\"text/html\""))
        XCTAssertTrue(html.contains("href=\"https://example.com\""))
        XCTAssertTrue(html.starts(with: "<link"))
    }

    func testHeaderRendering() {
        let link = APWebAuthenticationLink(uri: "https://example.com", parameters: ["rel": "prev"])
        let header = link.header
        XCTAssertEqual(header, "<https://example.com>; rel=\"prev\"")
    }

    func testInitFromHeader() {
        let header = "<https://example.com>; rel=\"next\"; type=\"text/html\""
        let link = APWebAuthenticationLink(header: header)
        XCTAssertEqual(link.uri, "https://example.com")
        XCTAssertEqual(link.parameters["rel"], "next")
        XCTAssertEqual(link.parameters["type"], "text/html")
    }

    func testParseLinkHeader_multipleLinks() {
        let header = "<https://a.com>; rel=\"first\", <https://b.com>; rel=\"next\""
        let links = parseLinkHeader(header)
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links[0].uri, "https://a.com")
        XCTAssertEqual(links[0].relationType, "first")
        XCTAssertEqual(links[1].uri, "https://b.com")
        XCTAssertEqual(links[1].relationType, "next")
    }

    func testLinkMatching_withParameters() {
        let link = APWebAuthenticationLink(uri: "https://x.com", parameters: ["rel": "next", "type": "json"])
        XCTAssertTrue(link.parameters ~= ["rel": "next"])
        XCTAssertTrue(link.parameters ~= ["rel": "next", "type": "json"])
        XCTAssertFalse(link.parameters ~= ["rel": "prev"])
    }

    func testDictionaryMergePlusOperator() {
        let a = ["a": "1"]
        let b = ["b": "2"]
        let merged = a + b
        XCTAssertEqual(merged["a"], "1")
        XCTAssertEqual(merged["b"], "2")
    }

    func testTrimFunction() {
        let trimBrackets = trim("<", ">")
        XCTAssertEqual(trimBrackets("<abc>"), "abc")
        XCTAssertEqual(trimBrackets("abc"), "abc")
    }

    func testFindLinkInHTTPURLResponse() {
        let headerFields = ["Link": "<https://api.example.com?page=2>; rel=\"next\""]
        let url = URL(string: "https://api.example.com?page=1")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headerFields)!

        let links = response.links
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].relationType, "next")
        XCTAssertEqual(links[0].uri, "https://api.example.com?page=2")

        let found = response.findLink("next")
        XCTAssertEqual(found?.uri, "https://api.example.com?page=2")
    }
}

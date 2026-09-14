import Alamofire
@testable import APWebAuthentication
import Foundation

/// In-process transport for `AuthClient` tests. Each test installs a handler
/// that maps the outgoing request to a canned response, so the full
/// interceptor → session → serializer pipeline runs without touching the
/// network.
final class MockURLProtocol: URLProtocol {

    typealias Handler = @Sendable (URLRequest) -> (HTTPURLResponse, Data?)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _handler: Handler?

    static var handler: Handler? {
        get { lock.withLock { _handler } }
        set { lock.withLock { _handler = newValue } }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func response(for request: URLRequest, status: Int, body: Data? = nil) -> (HTTPURLResponse, Data?) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: body == nil ? nil : ["Content-Type": "application/json"]
        )!
        return (response, body)
    }
}

/// `AuthClient` wired to `MockURLProtocol` with no authentication headers.
@MainActor
final class MockTransportClient: AuthClient {

    private struct NoOpInterceptor: RequestInterceptor {}

    init(baseURLString: String = "https://api.example.com/") {
        super.init(
            accountType: AccountStore.github,
            baseURLString: baseURLString,
            requestInterceptor: NoOpInterceptor()
        )
    }

    override func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = super.makeSessionConfiguration()
        configuration.protocolClasses = [MockURLProtocol.self]
        return configuration
    }
}

import Foundation

final class FixtureProtocol: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    static var replies: [(Int, String, [String: String])] = []
    static var calls: [URLRequest] = []
    static func reset(_ values: [(Int, String, [String: String])]) {
        lock.lock(); defer { lock.unlock() }
        replies = values; calls = []
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        Self.calls.append(request)
        let item = Self.replies.isEmpty ? (500, "{}", [:]) : Self.replies.removeFirst()
        Self.lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: item.0, httpVersion: "HTTP/1.1", headerFields: ["Content-Type":"application/json"].merging(item.2) { _, new in new })!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(item.1.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class FixtureClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date()
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return date }
    func advance(_ seconds: TimeInterval) { lock.lock(); defer { lock.unlock() }; date.addTimeInterval(seconds) }
}


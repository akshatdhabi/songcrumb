import Foundation

/// A deliberately small, single-request HTTP subset for the loopback companion.
/// No chunking, proxies, redirects, pipelining, or browser CORS access.
enum BridgeRequest {
    enum Result {
        case incomplete
        case rejected(String)
        case accepted(Playback?)
    }
    static func parse(_ data: Data, token: String, port: UInt16) -> Result {
        guard data.count <= 12_288 else { return .rejected("413 Content Too Large") }
        guard let separator = data.range(of: Data("\r\n\r\n".utf8)) else {
            return data.count > 4096 ? .rejected("431 Request Header Fields Too Large") : .incomplete
        }
        guard separator.lowerBound <= 4096,
              let header = String(data: data[..<separator.lowerBound], encoding: .ascii) else { return .rejected("400 Bad Request") }
        let lines = header.components(separatedBy: "\r\n")
        guard lines.first == "POST /v1/playback HTTP/1.1", lines.count <= 33 else { return .rejected("400 Bad Request") }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 2, !parts[0].isEmpty,
                  parts[0].range(of: #"^[A-Za-z0-9-]+$"#, options: .regularExpression) != nil,
                  !parts[1].unicodeScalars.contains(where: { $0.value < 32 && $0.value != 9 }) else { return .rejected("400 Bad Request") }
            let key = parts[0].lowercased()
            guard headers[key] == nil else { return .rejected("400 Bad Request") }
            headers[key] = parts[1].trimmingCharacters(in: .whitespaces)
        }
        guard headers["host"] == "127.0.0.1:\(port)", headers["transfer-encoding"] == nil,
              let length = headers["content-length"], length.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil,
              let count = Int(length), (1...8192).contains(count),
              headers["content-type"]?.split(separator: ";").first?.trimmingCharacters(in: .whitespaces).lowercased() == "application/json"
        else { return .rejected("400 Bad Request") }
        let supplied = Array((headers["authorization"] ?? "").utf8)
        let expected = Array("Bearer \(token)".utf8)
        guard !token.isEmpty, supplied.count == expected.count,
              zip(supplied, expected).reduce(UInt8(0), { $0 | ($1.0 ^ $1.1) }) == 0,
              validOrigin(headers["origin"]) else { return .rejected("403 Forbidden") }
        let body = data[separator.upperBound...]
        guard body.count <= count else { return .rejected("400 Bad Request") }
        guard body.count == count else { return .incomplete }
        guard let packet = try? JSONDecoder().decode(BrowserPlayback.self, from: Data(body)) else { return .rejected("422 Unprocessable Content") }
        if packet.valid, packet.playback() == nil { return .rejected("422 Unprocessable Content") }
        return .accepted(packet.playback())
    }
    private static func validOrigin(_ origin: String?) -> Bool {
        guard let origin else { return true } // Extension workers may omit Origin; the bearer token is still required.
        guard let url = URLComponents(string: origin), url.scheme == "chrome-extension",
              let host = url.host, host.range(of: #"^[a-p]{32}$"#, options: .regularExpression) != nil,
              url.user == nil, url.password == nil, url.port == nil, url.path.isEmpty,
              url.query == nil, url.fragment == nil else { return false }
        return true
    }
}

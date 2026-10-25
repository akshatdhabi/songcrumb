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

@main struct ProviderChecks {
    static func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw LyricsService.Failure.message(message) }
    }
    static func service() -> LyricsService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureProtocol.self]
        return LyricsService(session: URLSession(configuration: config))
    }
    static func main() async {
        do {
            var prefs = Preferences()
            let track = Playback(source: .youtubeMusic, trackID: "fixture", title: "Song (Official Music Video)", artist: "Artist", album: "Album", duration: 180, position: 0, playing: true)
            let plain = #"{"trackName":"Song","artistName":"Artist","albumName":"Album","duration":180,"plainLyrics":"Untimed fixture"}"#
            let correct = #"{"id":2,"trackName":"Song","artistName":"Artist","albumName":"Album","duration":180,"syncedLyrics":"[00:10]Correct fixture"}"#
            let live = #"{"id":1,"trackName":"Song (Live)","artistName":"Artist","duration":180,"syncedLyrics":"[00:01]Wrong version"}"#
            FixtureProtocol.reset([(200, plain, [:]), (200, "[\(live),\(correct)]", [:])])
            let first = service()
            let doc = try await first.fetch(track, preferences: prefs)
            try expect(doc.synced && doc.lines.first?.text == "Correct fixture", "Search must choose the correct synced recording, not the first result")
            try expect(FixtureProtocol.calls.count == 2, "Expected exact + one search request")
            try expect(FixtureProtocol.calls[0].url?.path == "/api/get" && FixtureProtocol.calls[1].url?.path == "/api/search", "Wrong endpoints")
            let query = URLComponents(url: FixtureProtocol.calls[0].url!, resolvingAgainstBaseURL: false)!.queryItems!
            try expect(query.first(where: { $0.name == "track_name" })?.value == "Song", "Presentation label was not normalized")
            _ = try await first.fetch(track, preferences: prefs)
            try expect(FixtureProtocol.calls.count == 2, "Session cache should avoid repeat lookups")

            FixtureProtocol.reset([(404,"{}",[:]), (200,"[]",[:])])
            let missing = service()
            do { _ = try await missing.fetch(track, preferences: prefs); throw LyricsService.Failure.message("No-match lookup should fail") }
            catch { try expect(error.localizedDescription.contains("No confident"), "No-match status was unclear") }
            do { _ = try await missing.fetch(track, preferences: prefs) } catch {}
            try expect(FixtureProtocol.calls.count == 2, "Negative cache should avoid repeated missing-record requests")

            FixtureProtocol.reset([(429,"{}",["Retry-After":"60"])])
            let busy = service()
            do { _ = try await busy.fetch(track, preferences: prefs) } catch {}
            do { _ = try await busy.fetch(track, preferences: prefs) } catch {}
            try expect(FixtureProtocol.calls.count == 1, "Retry-After must prevent another HTTP request")

            FixtureProtocol.reset([(200,correct,[:])])
            let automatic = try await service().fetch(track, preferences:Preferences())
            try expect(automatic.synced, "Public build must fetch without listener contact setup")
            try expect(FixtureProtocol.calls[0].value(forHTTPHeaderField:"User-Agent") == AppIdentity.userAgent, "Public identity must be the GitHub project URL")

            FixtureProtocol.reset([(200,plain,[:]), (200,"[]",[:])])
            let untimed = try await service().fetch(track, preferences: prefs)
            try expect(!untimed.synced && untimed.plain == "Untimed fixture", "Plain lyrics must remain explicitly unsynced")
            FixtureProtocol.reset([(200,plain,[:]), (503,"{}",["Retry-After":"60"])])
            let degraded = try await service().fetch(track, preferences:prefs)
            try expect(degraded.plain == "Untimed fixture", "Optional search failure must retain exact plain lyrics")

            let malformed = #"{"trackName":"Song","artistName":"Artist","duration":180,"syncedLyrics":"not actually LRC"}"#
            FixtureProtocol.reset([(200,malformed,[:]), (200,"[\(plain)]",[:])])
            let recovered = try await service().fetch(track, preferences:prefs)
            try expect(recovered.plain == "Untimed fixture", "Malformed timed data must not outrank valid plain lyrics")

            prefs.provider = "licensed"; prefs.licensedEndpoint = "https://provider.test/lyrics"
            FixtureProtocol.reset([(200,plain,[:])])
            do { _ = try await service().fetch(track, preferences:prefs); throw LyricsService.Failure.message("Missing licensing assertion was accepted") }
            catch { try expect(error.localizedDescription.contains("confirm display rights"), "Licensed rights gate failed") }
            let licensed = String(plain.dropLast()) + #", "licenseConfirmed":true,"attribution":"Fixture publisher","allowSessionCache":false}"#
            FixtureProtocol.reset([(200,licensed,[:]), (200,licensed,[:])])
            let contracted = service()
            _ = try await contracted.fetch(track, preferences:prefs)
            _ = try await contracted.fetch(track, preferences:prefs)
            try expect(FixtureProtocol.calls.count == 2, "Licensed content must not cache without permission")

            var unsafe = Preferences(); unsafe.width = 1e100; unsafe.fontSize = -.infinity; unsafe.source = "unknown"
            let safe = unsafe.sanitized()
            try expect(safe.width == 1000 && safe.fontSize == 18 && safe.source == "auto", "Persisted appearance must be clamped")
            print("Provider/preferences: 9 scenario groups passed, including degraded search, malformed timings, licence/cache policy and saved settings. No external requests.")
        } catch {
            fputs("Provider check failed: \(error)\n", stderr); exit(1)
        }
    }
}

import Foundation
import CoreGraphics
#if canImport(SongcrumbCore)
@testable import SongcrumbCore
#endif

struct CoreChecks {
    struct CheckFailure: Error { let description: String }
    func equal<T: Equatable>(_ a: T, _ b: T) throws { if a != b { throw CheckFailure(description: "Expected \(a) == \(b)") } }
    func isNil<T>(_ value: T?) throws { if value != nil { throw CheckFailure(description: "Expected nil") } }
    func isTrue(_ value: Bool) throws { if !value { throw CheckFailure(description: "Expected true") } }
    func isFalse(_ value: Bool) throws { try isTrue(!value) }
    func run() throws {
        try testRepeatedTimestampsOffsetAndSeek()
        try testPlainLyricsHaveNoInventedTiming()
        try testDuplicateAndMalformedLines()
        try testPlaybackPausesAndStaleHeartbeat()
        try testSourceArbitrationAndExplicitSelection()
        try testExactRecordingMatch()
        try testRejectInvalidBrowserPlayback()
        try testVersionAwareMatching()
        try testSafeIdentityAndPolicy()
        try testBridgeBoundaries()
        try testAttachedOverlayGeometry()
        print("Core: 11 scenario groups passed, including attached display geometry, identity, HTTP boundaries and redirect policy.")
    }
    func testAttachedOverlayGeometry() throws {
        // A notched display: visibleFrame starts below the menu bar.
        let visible = CGRect(x: 0, y: 38, width: 1470, height: 874)
        let attached = OverlayGeometry.attachedFrame(in: visible, requestedSize: CGSize(width: 560, height: 152))
        try equal(attached.maxY, visible.maxY)
        try equal(attached.midX, visible.midX)
        // External displays can use negative screen coordinates and smaller resolutions.
        let external = CGRect(x: -1024, y: -200, width: 1024, height: 768)
        let resized = OverlayGeometry.attachedFrame(in: external, requestedSize: CGSize(width: 1400, height: 1000))
        try isTrue(external.contains(resized))
        try equal(resized.maxY, external.maxY)
        try equal(resized.midX, external.midX)
    }
    func testRepeatedTimestampsOffsetAndSeek() throws {
        let doc = LRCParser.parse("[offset:+500]\n[00:02.5][00:08.050]Hello\n[00:04.123]World\n[00:05.00]\n[ar:Artist]", attribution: "Test")
        for (actual, expected) in zip(doc.lines.map(\.time), [2.0, 3.623, 4.5, 7.55]) { try isTrue(abs(actual - expected) < 0.000001) }
        try isNil(doc.activeIndex(at: 1.9))
        try equal(doc.activeIndex(at: 8), 3)
        try equal(doc.activeIndex(at: 2.1), 0) // backwards seek
        try equal(doc.activeIndex(at: 1.8, adjustment: 0.3), 0)
        try equal(doc.lines[2].text, "♪")
    }
    func testPlainLyricsHaveNoInventedTiming() throws {
        let doc = LRCParser.parse("A line\nAnother line", attribution: "Local")
        try isFalse(doc.synced)
        try isNil(doc.activeIndex(at: 200))
        try equal(doc.plain, "A line\nAnother line")
    }
    func testDuplicateAndMalformedLines() throws {
        let doc = LRCParser.parse("[00:01]One\n[00:01]Deux\n[00:99]Invalid\n[00:03.1]Three", attribution: "Test")
        try equal(doc.lines.count, 2)
        try isTrue(doc.lines[0].text.contains("One"))
        try isTrue(doc.lines[0].text.contains("Deux"))
        try equal(doc.lines[1].time, 3.1)
    }
    func testPlaybackPausesAndStaleHeartbeat() throws {
        var track = Playback(source: .spotify, trackID: "1", title: "Song", artist: "A", album: "", duration: 120, position: 10, playing: true, sampledAt: 100)
        try equal(track.position(at: 101), 11)
        try equal(track.position(at: 200), 13)
        track.playing = false
        try equal(track.position(at: 101), 10)
    }
    func testSourceArbitrationAndExplicitSelection() throws {
        let a = Playback(source: .spotify, trackID: "a", title: "A", artist: "", album: "", duration: 100, position: 0, playing: false)
        var b = a; b.source = .youtubeMusic; b.playing = true
        try equal(SourceSelection.choose([a,b], preferred: "auto", current: .spotify)?.source, .youtubeMusic)
        try equal(SourceSelection.choose([a,b], preferred: "spotify", current: .youtubeMusic)?.source, .spotify)
        try isNil(SourceSelection.choose([b], preferred: "appleMusic", current: nil))
    }
    func testExactRecordingMatch() throws {
        let record = try JSONDecoder().decode(LyricsRecord.self, from: Data(#"{"trackName":"Song","artistName":"Artist","duration":100,"syncedLyrics":"[00:01]Hi"}"#.utf8))
        var track = Playback(source: .spotify, trackID: "a", title: "song", artist: "Artist", album: "", duration: 101.9, position: 0, playing: true)
        try isTrue(record.matches(track))
        track.duration = 105
        try isFalse(record.matches(track))
    }
    func testRejectInvalidBrowserPlayback() throws {
        let packet = BrowserPlayback(trackID: "a", title: "A", artist: "", album: "", duration: 100, position: -1, playing: true, rate: 1, valid: true)
        try isNil(packet.playback())
    }
    func testVersionAwareMatching() throws {
        let record = try JSONDecoder().decode(LyricsRecord.self, from: Data(#"{"trackName":"Song","artistName":"Artist & Guest","albumName":"Album","duration":180,"syncedLyrics":"[00:01]Hi"}"#.utf8))
        var track = Playback(source: .youtubeMusic, trackID: "v", title: "Song (Official Music Video)", artist: "Guest, Artist", album: "", duration: 181, position: 0, playing: true)
        try isTrue(record.matches(track))
        track.title = "Song (Live)"
        try isFalse(record.matches(track))
        track.title = "Song (Remastered 2024)"
        try isFalse(record.matches(track))
        track.title = "Song"; track.artist = "Someone else"
        try isFalse(record.matches(track))
        try equal(RecordingMatcher.cleanTitle("Song - Official Audio"), "Song")
        try equal(RecordingMatcher.cleanTitle("Song (Acoustic)"), "Song (Acoustic)")
    }

    func testSafeIdentityAndPolicy() throws {
        let a = Playback(source: .spotify, trackID: "A|B", title: "C", artist: "Artist", album: "", duration: 100, position: 0, playing: true)
        let b = Playback(source: .spotify, trackID: "A", title: "B|C", artist: "Artist", album: "", duration: 100, position: 0, playing: true)
        try equal(a.legacyKey, b.legacyKey)
        try isFalse(a.key == b.key)
        let good = URL(string:"https://provider.test/a")!
        try isTrue(ProviderPolicy.sameHTTPSOrigin(good, URL(string:"https://provider.test/b")!))
        try isFalse(ProviderPolicy.sameHTTPSOrigin(good, URL(string:"https://other.test/b")!))
        try isFalse(ProviderPolicy.sameHTTPSOrigin(good, URL(string:"http://provider.test/b")!))
        try isFalse(ProviderPolicy.sameHTTPSOrigin(good, URL(string:"https://provider.test:444/b")!))
        try isFalse(ProviderPolicy.sameHTTPSOrigin(good, URL(string:"https://user:pass@provider.test/b")!))
        try equal(AppIdentity.projectURL.absoluteString, "https://github.com/akshatdhabi/songcrumb")
        try isFalse(AppIdentity.userAgent.contains("@"))
    }
    func testBridgeBoundaries() throws {
        let body = #"{"trackID":"fixture","title":"Song","artist":"A","album":"","duration":100,"position":1,"playing":true,"rate":1,"valid":true}"#
        let token = String(repeating:"a",count:64)
        func request(extra: String = "", host: String = "127.0.0.1:48537", mime: String = "application/json", content: String? = nil) -> Data {
            let text = content ?? body
            return Data("POST /v1/playback HTTP/1.1\r\nHost: \(host)\r\nAuthorization: Bearer \(token)\r\nContent-Type: \(mime)\r\nContent-Length: \(text.utf8.count)\r\n\(extra)\r\n\(text)".utf8)
        }
        func rejected(_ data: Data) throws {
            if case .rejected = BridgeRequest.parse(data, token:token, port:48537) {} else { throw CheckFailure(description:"Unsafe bridge request accepted") }
        }
        if case .accepted(let track) = BridgeRequest.parse(request(), token:token, port:48537) { try equal(track?.title,"Song") }
        else { throw CheckFailure(description:"Valid bridge request rejected") }
        let fragmented = request().dropLast(5)
        if case .incomplete = BridgeRequest.parse(Data(fragmented), token:token, port:48537) {} else { throw CheckFailure(description:"Partial body must wait") }
        try rejected(request(extra:"Content-Length: 1\r\n"))
        try rejected(request(extra:"Authorization: Bearer wrong\r\n"))
        try rejected(request(extra:"Transfer-Encoding: chunked\r\n"))
        try rejected(request(extra:"Origin: https://hostile.test\r\n"))
        try rejected(request(extra:"Origin: chrome-extension://invalid\r\n"))
        try rejected(request(host:"rebind.hostile.test:48537"))
        try rejected(request(mime:"application/json-hostile"))
        var pipelined = request(); pipelined.append(Data("GET / HTTP/1.1\r\n\r\n".utf8))
        try rejected(pipelined)
    }
}

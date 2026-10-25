import Foundation

enum MusicSource: String, Codable, CaseIterable, Identifiable {
    case spotify, appleMusic, youtubeMusic, demo
    var id: String { rawValue }
    var name: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        case .youtubeMusic: return "YouTube Music"
        case .demo: return "Preview"
        }
    }
    var bundleID: String {
        self == .spotify ? "com.spotify.client" : "com.apple.Music"
    }
}

struct Playback: Equatable {
    var source: MusicSource
    var trackID: String
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var position: Double
    var playing: Bool
    var rate: Double = 1
    var sampledAt: TimeInterval = ProcessInfo.processInfo.systemUptime
    var key: String {
        [source.rawValue, trackID, title, artist, album, String(duration)]
            .map { "\($0.utf8.count):\($0)" }.joined()
    }
    var legacyKey: String { "\(source.rawValue)|\(trackID)|\(title)|\(artist)|\(duration)" }
    func position(at uptime: TimeInterval) -> Double {
        // Freeze after a missing heartbeat instead of drifting indefinitely.
        let elapsed = playing ? min(3, max(0, uptime - sampledAt)) * rate : 0
        return min(max(0, duration), max(0, position + elapsed))
    }
}

enum SourceSelection {
    static func choose(_ candidates: [Playback], preferred: String, current: MusicSource?) -> Playback? {
        let eligible = preferred == "auto" ? candidates : candidates.filter { $0.source.rawValue == preferred }
        let playing = eligible.filter(\.playing)
        // Keep a playing source stable when two apps play at once.
        return playing.first(where: { $0.source == current }) ?? playing.first
            ?? eligible.first(where: { $0.source == current }) ?? eligible.first
    }
}

struct BrowserPlayback: Codable {
    var trackID: String
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var position: Double
    var playing: Bool
    var rate: Double
    var valid: Bool
    func playback() -> Playback? {
        guard valid, !title.isEmpty, title.count <= 500, artist.count <= 500,
              trackID.count <= 200, album.count <= 500, duration.isFinite,
              duration > 0, duration <= 86_400, position.isFinite,
              position >= 0, position <= duration + 2, rate.isFinite,
              (0.25...4).contains(rate) else { return nil }
        return Playback(source: .youtubeMusic, trackID: trackID, title: title,
                        artist: artist, album: album, duration: duration,
                        position: position, playing: playing, rate: rate)
    }
}

import Foundation

enum RecordingMatcher {
    /// Remove presentation labels, while retaining recording versions such as live/acoustic/remix.
    static func cleanTitle(_ title: String) -> String {
        let labels = #"(?:official\s+(?:music\s+)?(?:video|audio|visuali[sz]er)|(?:official\s+)?lyric(?:s|\s+video)|audio\s+only)"#
        var result = title.replacingOccurrences(of: "[\\[(]\\s*" + labels + "(?:\\s*[-·|]?\\s*(?:hd|4k|hq))?\\s*[\\])]", with: "", options: [.regularExpression, .caseInsensitive])
        result = result.replacingOccurrences(of: "\\s*[-–—|]\\s*" + labels + "\\s*$", with: "", options: [.regularExpression, .caseInsensitive])
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static func normalized(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let stripped = folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || CharacterSet.whitespacesAndNewlines.contains($0) }
        return String(String.UnicodeScalarView(stripped)).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    private static func artistKey(_ artist: String) -> String {
        // Formatting-only changes in collaborations are safe; guessing a missing artist is not.
        artist.replacingOccurrences(of: #"\s+(?:feat\.?|ft\.?|featuring|and)\s+|\s*[&,;]\s*"#,
                                     with: "|", options: [.regularExpression, .caseInsensitive])
            .components(separatedBy: "|").map(normalized).filter { !$0.isEmpty }.sorted().joined(separator: "|")
    }
    static func matches(_ record: LyricsRecord, track: Playback) -> Bool {
        guard let title = record.trackName, let artist = record.artistName, let duration = record.duration,
              duration.isFinite, abs(duration - track.duration) <= 2 else { return false }
        let sourceTitle = normalized(cleanTitle(track.title))
        return !sourceTitle.isEmpty && normalized(cleanTitle(title)) == sourceTitle
            && !artistKey(track.artist).isEmpty && artistKey(artist) == artistKey(track.artist)
    }
    static func best(in records: [LyricsRecord], for track: Playback) -> LyricsRecord? {
        records.filter { matches($0, track: track) }.max { score($0, track: track) < score($1, track: track) }
    }
    private static func score(_ record: LyricsRecord, track: Playback) -> Double {
        var score = 100 - abs((record.duration ?? 0) - track.duration) * 10
        if !track.album.isEmpty, normalized(record.albumName ?? "") == normalized(track.album) { score += 30 }
        if normalized(record.trackName ?? "") == normalized(track.title) { score += 5 }
        if !(record.syncedLyrics ?? "").isEmpty { score += 3 }
        return score
    }
}

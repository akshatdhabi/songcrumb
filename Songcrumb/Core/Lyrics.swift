import Foundation

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: Double
    let text: String
}

struct LyricsDocument: Equatable {
    var lines: [LyricLine] = []
    var plain: String = ""
    var attribution: String = ""
    var instrumental = false
    var synced: Bool { !lines.isEmpty }
    func activeIndex(at position: Double, adjustment: Double = 0) -> Int? {
        let time = position + adjustment
        var low = 0, high = lines.count
        while low < high {
            let middle = (low + high) / 2
            if lines[middle].time <= time { low = middle + 1 } else { high = middle }
        }
        return low == 0 ? nil : low - 1
    }
}

enum LRCParser {
    static func parse(_ input: String, attribution: String) -> LyricsDocument {
        let pattern = try! NSRegularExpression(pattern: #"\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]"#)
        let offsetPattern = try! NSRegularExpression(pattern: #"(?i)\[offset:([+-]?\d+)\]"#)
        var offset = 0.0
        let range = NSRange(input.startIndex..., in: input)
        if let match = offsetPattern.firstMatch(in: input, range: range),
           let r = Range(match.range(at: 1), in: input), let ms = Double(input[r]) { offset = ms / 1000 }
        var rows: [(Double, String)] = []
        for raw in input.components(separatedBy: .newlines) {
            let matches = pattern.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
            guard let last = matches.last, let textRange = Range(last.range, in: raw) else { continue }
            let text = String(raw[textRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            for match in matches {
                func value(_ index: Int) -> String {
                    Range(match.range(at: index), in: raw).map { String(raw[$0]) } ?? ""
                }
                guard let minutes = Double(value(1)), let seconds = Double(value(2)), seconds < 60 else { continue }
                let fraction = value(3)
                let sub = Double("0." + fraction) ?? 0
                rows.append((max(0, minutes * 60 + seconds + sub - offset), text.isEmpty ? "♪" : text))
            }
        }
        rows = rows.enumerated().sorted { a, b in a.element.0 == b.element.0 ? a.offset < b.offset : a.element.0 < b.element.0 }.map(\.element)
        // Merge simultaneous lines so duets / translations appear together.
        var merged: [(Double, String)] = []
        var groupTime: Double?
        var groupText: [String] = []
        for row in rows {
            if let time = groupTime, abs(time - row.0) < 0.0001 {
                if groupText.last != row.1 { groupText.append(row.1) }
            } else {
                if let time = groupTime { merged.append((time, groupText.joined(separator: "\n"))) }
                groupTime = row.0
                groupText.removeAll(keepingCapacity: true)
                groupText.append(row.1)
            }
        }
        if let time = groupTime { merged.append((time, groupText.joined(separator: "\n"))) }
        return LyricsDocument(lines: merged.enumerated().map { LyricLine(id: $0.offset, time: $0.element.0, text: $0.element.1) },
                              plain: rows.isEmpty ? input : "", attribution: attribution)
    }
}

struct LyricsRecord: Decodable {
    var id: Int?
    var trackName: String?
    var artistName: String?
    var albumName: String?
    var duration: Double?
    var instrumental: Bool?
    var plainLyrics: String?
    var syncedLyrics: String?
    var attribution: String?
    var licenseConfirmed: Bool?
    var allowSessionCache: Bool?
    var hasUsableSyncedLyrics: Bool {
        guard let syncedLyrics, !syncedLyrics.isEmpty else { return false }
        return !LRCParser.parse(syncedLyrics, attribution: "").lines.isEmpty
    }
    var isUsable: Bool {
        instrumental == true || !(plainLyrics ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasUsableSyncedLyrics
    }
    func document(attribution fallback: String) -> LyricsDocument {
        var result = LRCParser.parse(syncedLyrics ?? "", attribution: attribution ?? fallback)
        result.plain = plainLyrics ?? ""
        result.instrumental = instrumental ?? false
        return result
    }
    func matches(_ track: Playback) -> Bool {
        RecordingMatcher.matches(self, track: track)
    }
}

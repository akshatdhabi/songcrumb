import AppKit
import SwiftUI

struct Preferences: Codable, Equatable {
    var spotify = false
    var appleMusic = false
    var youtubeMusic = false
    var source = "auto"
    var provider = "lrclib"
    var automaticLookupVersion: Int? = 2
    var licensedEndpoint = ""
    var typeface: String? = "mono"
    var lyricFontDesign: Font.Design { typeface == "rounded" ? .rounded : (typeface == "system" ? .default : .monospaced) }
    var attachedDisplayID: String?
    var placement: String? = "top"
    var topAttached: Bool { placement != "floating" }
    var fontSize = 18.0
    var width = 560.0
    var textOpacity = 1.0
    var backgroundOpacity = 0.82
    var accent = "white"
    var contextLines = true
    var showTrack = true
    var hidePaused = false
    var visible = true
    var adjustment = 0.0
    static func load() -> Preferences {
        guard let data = UserDefaults.standard.data(forKey: "preferences"),
              var value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        if value.automaticLookupVersion == nil {
            if value.provider == "local" { value.provider = "lrclib" }
            value.automaticLookupVersion = 2
        }
        return value.sanitized()
    }
    func sanitized() -> Self {
        var value = self
        func clamp(_ number: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
            number.isFinite ? min(range.upperBound, max(range.lowerBound, number)) : fallback
        }
        value.fontSize = clamp(fontSize, 16...44, 18)
        value.width = clamp(width, 360...1000, 560)
        value.textOpacity = clamp(textOpacity, 0.25...1, 1)
        value.backgroundOpacity = clamp(backgroundOpacity, 0...0.9, 0.82)
        value.adjustment = clamp(adjustment, -10...10, 0)
        if !["mono", "rounded", "system"].contains(typeface ?? "mono") { value.typeface = "mono" }
        if !["top", "floating"].contains(placement ?? "top") { value.placement = "top" }
        if !["auto", "spotify", "appleMusic", "youtubeMusic"].contains(source) { value.source = "auto" }
        if !["local", "lrclib", "licensed"].contains(provider) { value.provider = "lrclib" }
        if !["lavender", "mint", "peach", "white"].contains(accent) { value.accent = "lavender" }
        return value
    }
    func save() { UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: "preferences") }
    var tint: Color {
        switch accent {
        case "mint": return Color(red: 0.53, green: 0.96, blue: 0.79)
        case "white": return .white
        case "peach": return Color(red: 1, green: 0.76, blue: 0.61)
        default: return Color(red: 0.78, green: 0.73, blue: 1)
        }
    }
}

enum LocalLyrics {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Songcrumb/LocalLyrics", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

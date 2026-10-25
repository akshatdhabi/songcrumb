import AppKit

@main struct AppChecks {
    @MainActor static func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw LyricsService.Failure.message(message) }
    }
    @MainActor static func wait(until condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw LyricsService.Failure.message("App lifecycle condition timed out")
    }
    @MainActor static func main() async {
        do {
            _ = NSApplication.shared
            var prefs = Preferences(); prefs.visible = false
            prefs.attachedDisplayID = DisplayCatalog.connected.last?.id ?? "disconnected-fixture"
            let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [FixtureProtocol.self]
            let service = LyricsService(session: URLSession(configuration: config), jitter: { 0 })
            let model = AppModel(preferences: prefs, service: service, startServices: false)
            defer { model.shutdown() }
            let chosen = model.preferences.attachedDisplayID
            let overlay = OverlayController(model: model)
            try expect(model.preferences.attachedDisplayID == chosen, "Overlay initialization replaced the saved monitor with the pointer's screen")
            if let screen = DisplayCatalog.screen(preferred: chosen) {
                try expect(abs(overlay.panel.frame.maxY - screen.frame.maxY) < 0.5, "Attached backdrop does not reach the physical top")
                try expect(model.overlayTopInset >= screen.safeAreaInsets.top, "Text is not clear of the notch")
            }
            let track = Playback(source: .spotify, trackID: "app-fixture", title: "Fixture", artist: "Original", album: "", duration: 180, position: 0, playing: true)
            let correct = #"{"trackName":"Fixture","artistName":"Original","duration":180,"syncedLyrics":"[00:00]Original fixture line"}"#
            FixtureProtocol.reset([(503,"{}",["Retry-After":"1"]), (200,correct,[:])])
            model.playback = track; model.loadLyrics()
            try await wait { model.retryAt != nil }
            try expect(!model.loading, "Cooldown must show a quiet waiting state")
            try await wait { model.lyrics != nil && model.retryAt == nil }
            try expect(FixtureProtocol.calls.count == 2, "The current song did not retry automatically exactly once")

            FixtureProtocol.reset([(429,"{}",["Retry-After":"60"])])
            model.clearSessionCache()
            try await wait { model.retryAt != nil }
            try expect(model.lyrics != nil, "Refresh erased usable current lyrics during provider backoff")
            var other = track; other.trackID = "next-song"
            model.playback = other; model.loadLyrics()
            try await wait { model.retryAt != nil }
            try expect(model.lyrics == nil, "A new recording retained the previous song's lyrics")
            try expect(FixtureProtocol.calls.count == 1, "A track change bypassed the origin's cooldown")
            model.toggleDemo()
            try expect(model.retryAt == nil && model.demo, "Preview did not cancel the pending retry")
            model.shutdown()
            print("App lifecycle: saved monitor, physical-edge/notch layout, automatic recovery, preserved refresh lyrics, source cooldown and preview cancellation passed. No external requests or music app changes.")
        } catch {
            fputs("App check failed: \(error)\n", stderr); exit(1)
        }
    }
}

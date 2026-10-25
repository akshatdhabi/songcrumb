import AppKit
import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor final class AppModel: ObservableObject {
    @Published var preferences = Preferences.load() {
        didSet {
            preferences.save()
            if !preferences.visible { editing = false }
            if oldValue.youtubeMusic != preferences.youtubeMusic { updateBridge() }
            if oldValue.spotify != preferences.spotify || oldValue.appleMusic != preferences.appleMusic || oldValue.source != preferences.source {
                Task { await poll() }
            }
        }
    }
    @Published var playback: Playback?
    @Published var lyrics: LyricsDocument?
    @Published var lyricsStatus = "Connect your music for automatic online lyrics."
    @Published var playerStatus: [String: String] = [:]
    @Published var browserStatus = "Disabled"
    @Published var editing = false {
        didSet { if editing && !preferences.visible { preferences.visible = true } }
    }
    @Published var demo = false
    @Published var suspended = false
    @Published var loading = false
    @Published var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published var token: String = UserDefaults.standard.string(forKey: "browserToken") ?? ""
    private let desktop = DesktopPlayer()
    private let service = LyricsService()
    private let bridge = BrowserBridge()
    private var browserPlayback: Playback?
    private var desktopPlayback: [Playback] = []
    private var browserReceived = 0.0
    private var pollTask: Task<Void, Never>?
    private var lyricTask: Task<Void, Never>?
    private var denied: Set<MusicSource> = []
    private var retryDates: [MusicSource: Date] = [:]
    private var observers: [NSObjectProtocol] = []
    private var requestID = UUID()
    private var demoStart = 0.0
    var panelChanged: (() -> Void)?
    var showSettings: (() -> Void)?

    init() {
        if token.isEmpty { rotateToken() }
        bridge.onPlayback = { [weak self] track in
            Task { @MainActor in
                guard let self, self.preferences.youtubeMusic, !self.suspended else { return }
                self.browserPlayback = track; self.browserReceived = ProcessInfo.processInfo.systemUptime
                if !self.demo { self.updateSelection() }
            }
        }
        bridge.onStatus = { [weak self] status in Task { @MainActor in self?.browserStatus = status } }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleep() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleep() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.wake() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.wake() }
        })
        startPolling()
        updateBridge()
    }
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if !self.suspended { await self.poll() }
                let interval = self.suspended ? 10.0 : (self.playback?.playing == true ? (self.lowPower || !self.preferences.visible ? 2.0 : 1.0) : 3.0)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }
    private func sleep() {
        suspended = true; browserPlayback = nil; desktopPlayback = []; playback = nil
        pollTask?.cancel(); pollTask = nil
        lyricTask?.cancel(); requestID = UUID(); bridge.stop(); panelChanged?()
    }
    private func wake() {
        suspended = false; updateBridge()
        startPolling()
    }
    func updateBridge() {
        if preferences.youtubeMusic && !suspended { bridge.start(token: token) }
        else {
            bridge.stop(); browserPlayback = nil; browserReceived = 0; browserStatus = "Disabled"
            if !demo { updateSelection() }
        }
    }
    func rotateToken() {
        token = UUID().uuidString.replacingOccurrences(of: "-", with: "") + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        UserDefaults.standard.set(token, forKey: "browserToken")
        browserPlayback = nil; browserReceived = 0
        bridge.stop()
        if preferences.youtubeMusic { bridge.start(token: token) }
    }
    func copyToken() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(token, forType: .string) }
    func retryAutomation() { denied.removeAll(); retryDates.removeAll(); Task { await poll() } }
    private var polling = false
    func poll() async {
        guard !polling, !suspended else { return }
        polling = true; defer { polling = false }
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        if demo {
            playback = Playback(source: .demo, trackID: "preview", title: "A little room for music", artist: "Songcrumb · original preview", album: "", duration: 30, position: (ProcessInfo.processInfo.systemUptime - demoStart).truncatingRemainder(dividingBy: 30), playing: true)
            panelChanged?(); return
        }
        var candidates: [Playback] = []
        for source in [MusicSource.spotify, .appleMusic] {
            let enabled = source == .spotify ? preferences.spotify : preferences.appleMusic
            guard enabled else { playerStatus[source.rawValue] = "Not connected"; continue }
            guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: source.bundleID).first, let appURL = running.bundleURL else {
                playerStatus[source.rawValue] = "Open the desktop app to connect"; continue
            }
            guard !denied.contains(source) else { continue }
            guard retryDates[source, default: .distantPast] < Date() else { continue }
            let result = await desktop.read(source, processID: running.processIdentifier, applicationURL: appURL)
            guard !suspended, !demo, !Task.isCancelled else { return }
            switch result {
            case .success(let track):
                playerStatus[source.rawValue] = track == nil ? "Waiting for a song" : "Connected"
                if let track { candidates.append(track) }
            case .failure(let error):
                if error.code == -1743 {
                    denied.insert(source)
                    playerStatus[source.rawValue] = "Automation denied. Allow Songcrumb in System Settings → Privacy & Security → Automation, then Retry."
                } else {
                    retryDates[source] = Date().addingTimeInterval(15)
                    playerStatus[source.rawValue] = "Could not read playback (\(error.code)). Retry or open a local song."
                }
            }
        }
        desktopPlayback = candidates
        updateSelection()
    }
    private func updateSelection() {
        var candidates = desktopPlayback.filter { $0.source == .spotify ? preferences.spotify : preferences.appleMusic }
        if preferences.youtubeMusic, ProcessInfo.processInfo.systemUptime - browserReceived < 5,
           let browserPlayback { candidates.append(browserPlayback) }
        let selected = SourceSelection.choose(candidates, preferred: preferences.source, current: playback?.source)
        let previousKey = playback?.key
        playback = selected
        if selected?.key != previousKey {
            preferences.adjustment = 0
            loadLyrics()
        }
        panelChanged?()
    }
    func loadLyrics() {
        let previous = lyricTask
        previous?.cancel(); requestID = UUID()
        loading = false; lyrics = nil
        guard let track = playback else { lyricsStatus = "Play a song in a connected source."; return }
        if demo { installPreview(); return }
        if let data = localLyrics(track) {
            lyrics = LRCParser.parse(data, attribution: "Your local lyrics")
            lyricsStatus = "Local lyrics"; return
        }
        let id = requestID, prefs = preferences
        loading = true; lyricsStatus = "Finding this recording…"
        lyricTask = Task { [weak self] in
            // Join cancelled work before the next request; rapid track skips cannot flood a provider.
            await previous?.value
            guard !Task.isCancelled else { return }
            guard let self else { return }
            do {
                let doc = try await service.fetch(track, preferences: prefs)
                guard !Task.isCancelled, requestID == id, playback?.key == track.key else { return }
                lyrics = doc; lyricsStatus = doc.instrumental ? "Instrumental" : (doc.synced ? "Line synced" : "Unsynced · scroll manually")
            } catch {
                guard !Task.isCancelled, requestID == id else { return }
                lyricsStatus = error.localizedDescription
            }
            loading = false
        }
    }
    private func localURL(_ track: Playback, legacy: Bool = false) -> URL {
        let name = SHA256.hash(data: Data((legacy ? track.legacyKey : track.key).utf8)).map { String(format: "%02x", $0) }.joined()
        return LocalLyrics.directory.appendingPathComponent(name + ".txt")
    }
    private func localLyrics(_ track: Playback) -> String? {
        for url in [localURL(track), localURL(track, legacy: true)] {
            guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 512_000,
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            return text
        }
        return nil
    }
    func importLyrics() {
        guard let track = playback, !demo else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "lrc") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.message = "Choose lyrics you have permission to display. They will be associated with ‘\(track.title)’."
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                guard let self else { return }
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    guard (attributes[.size] as? Int ?? Int.max) <= 512_000 else { throw LyricsService.Failure.message("Choose a lyrics file smaller than 512 KB.") }
                    let text = try String(contentsOf: url, encoding: .utf8)
                    try text.write(to: self.localURL(track), atomically: true, encoding: .utf8)
                    if self.playback?.key == track.key { self.loadLyrics() }
                } catch { self.lyricsStatus = "Could not import: \(error.localizedDescription)" }
            }
        }
    }
    func removeLocalLyrics() {
        if let track = playback {
            try? FileManager.default.removeItem(at: localURL(track))
            try? FileManager.default.removeItem(at: localURL(track, legacy: true))
            loadLyrics()
        }
    }
    func clearSessionCache() { Task { await service.clear(); loadLyrics() } }
    func toggleDemo() {
        demo.toggle(); lyricTask?.cancel(); requestID = UUID()
        if demo {
            demoStart = ProcessInfo.processInfo.systemUptime
            playback = Playback(source: .demo, trackID: "preview", title: "A little room for music", artist: "Songcrumb · original preview", album: "", duration: 30, position: 0, playing: true)
            installPreview()
        }
        else { playback = nil; lyrics = nil }
        panelChanged?()
        Task { await poll() }
    }
    func shutdown() {
        pollTask?.cancel(); lyricTask?.cancel(); bridge.stop()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }
    private func installPreview() {
        lyrics = LRCParser.parse("""
        [00:00]A little room for music
        [00:05]Let the light fall into place
        [00:10]Every word a little closer
        [00:15]Every note a softer space
        [00:20]Keep a little room for music
        [00:25]Let it follow through your day
        """, attribution: "Songcrumb · original demo lyrics")
        loading = false; lyricsStatus = "Original preview · no music playing"
    }
}

import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let resetPosition: () -> Void
    @State private var section: SettingsSection = .sources
    private let brand = Color(red: 1, green: 0.76, blue: 0.61)
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 9) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 34, height: 34)
                    Text("songcrumb").font(.system(size: 18, weight: .semibold)).tracking(-0.6)
                }.padding(.bottom, 30)
                ForEach(SettingsSection.allCases) { item in
                    Button { section = item } label: {
                        Label(item.title, systemImage: item.icon)
                            .font(.system(size: 12, weight: section == item ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 11)
                            .foregroundStyle(section == item ? brand : .secondary)
                            .background(section == item ? brand.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
                Spacer()
                Text("Keep the words close.").font(.system(size: 12, design: .serif)).italic().foregroundStyle(brand.opacity(0.8))
                Text("Native on your Mac").font(.caption2).foregroundStyle(.tertiary)
            }.padding(18).frame(width: 204).background(.black.opacity(0.16))
            Divider()
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title).font(.system(size: 25, weight: .semibold)).tracking(-0.7)
                        Text(section.subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(model.demo ? "End preview" : "Preview") { model.toggleDemo() }
                        .buttonStyle(.bordered).controlSize(.small)
                }.padding(.horizontal, 26).padding(.top, 26).padding(.bottom, 16)
                Group {
                    switch section {
                    case .sources: sources
                    case .appearance: appearance
                    case .lyrics: lyrics
                    case .about: about
                    }
                }
            }
        }
        .frame(width: 820, height: 700)
        .tint(brand)
        .preferredColorScheme(.dark)
    }
    private enum SettingsSection: String, CaseIterable, Identifiable {
        case sources, appearance, lyrics, about
        var id: String { rawValue }
        var title: String {
            switch self { case .sources: return "Music connections"; case .appearance: return "Your overlay"; case .lyrics: return "Lyrics & timing"; case .about: return "About Songcrumb" }
        }
        var subtitle: String {
            switch self { case .sources: return "Connect the music you already love."; case .appearance: return "A quiet place for the words. Make it yours."; case .lyrics: return "Automatic lookup, with room for fine tuning."; case .about: return "A little Mac app for your everyday soundtrack." }
        }
        var icon: String {
            switch self { case .sources: return "waveform"; case .appearance: return "rectangle.topthird.inset.filled"; case .lyrics: return "text.alignleft"; case .about: return "info.circle" }
        }
    }
    private var sources: some View {
        Form {
            Section {
                Text("Connect only the sources you use. Songcrumb never starts a music app or changes its playback.")
                    .font(.callout).foregroundStyle(.secondary)
                Toggle("Spotify desktop", isOn: $model.preferences.spotify)
                Text(model.playerStatus["spotify"] ?? "Not connected").font(.caption).foregroundStyle(.secondary)
                Toggle("Apple Music desktop", isOn: $model.preferences.appleMusic)
                Text(model.playerStatus["appleMusic"] ?? "Not connected").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Retry Automation") { model.retryAutomation() }
                    Button("Privacy settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!) }
                }
                Text("The first desktop connection asks macOS for Automation permission for that app. Accessibility, microphone and screen recording are never needed.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text("On your Mac") }
            Section {
                Toggle("YouTube Music browser companion", isOn: $model.preferences.youtubeMusic)
                Text(model.browserStatus).font(.caption).foregroundStyle(.secondary)
                Text("Load the included YouTubeMusicCompanion folder as an unpacked extension in Chrome, Edge or Brave. Copy the pairing token below into its popup, then open music.youtube.com. See README for steps. Safari requires a separately packaged extension and is not included.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Copy pairing token") { model.copyToken() }
                    Button("Reset pairing") { model.rotateToken() }
                }
            } header: { Text("YouTube Music") }
            Section {
                Picker("Listen to", selection: $model.preferences.source) {
                    Text("Automatic").tag("auto")
                    ForEach([MusicSource.spotify, .appleMusic, .youtubeMusic]) { Text($0.name).tag($0.rawValue) }
                }
                Text("Automatic keeps the current playing source, then prefers Spotify, Apple Music and YouTube Music. Choose a source if several are playing.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
    private var appearance: some View {
        Form {
            Section {
                Picker("Position", selection: Binding(get: { model.preferences.placement ?? "top" }, set: { model.preferences.placement = $0 })) {
                    Text("Attached").tag("top")
                    Text("Floating").tag("floating")
                }.pickerStyle(.segmented)
                if model.preferences.topAttached {
                    DisplayPicker(model: model)
                    Text("Stays on your chosen display, including full-screen Spaces. The backdrop follows the top edge when the menu bar hides; lyrics stay clear of the camera notch.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button(model.editing ? "Lock · click through" : "Unlock controls") { model.editing.toggle() }
                    Spacer()
                    Button(model.preferences.topAttached ? "Use pointer’s display" : "Reset position") { resetPosition() }
                }
            } header: { Text("A place on your screen") }
            Section {
                VStack(alignment: .leading, spacing: 9) {
                    Text("A little room for music").foregroundStyle(.white.opacity(0.3))
                    Text("Let the light fall into place").foregroundStyle(model.preferences.tint).fontWeight(.medium)
                    Text("Every word a little closer").foregroundStyle(.white.opacity(0.3))
                }
                .font(.system(size: min(23, model.preferences.fontSize), design: model.preferences.lyricFontDesign))
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(model.preferences.backgroundOpacity), in: RoundedRectangle(cornerRadius: 14))
                .opacity(model.preferences.textOpacity).accessibilityLabel("Typography preview with original sample text")
                Picker("Typeface", selection: Binding(get: { model.preferences.typeface ?? "mono" }, set: { model.preferences.typeface = $0 })) {
                    Text("Monospaced").tag("mono"); Text("Rounded").tag("rounded"); Text("System").tag("system")
                }.pickerStyle(.segmented)
                control("Type size", value: $model.preferences.fontSize, range: 16...44, suffix: "pt")
                Picker("Highlight", selection: $model.preferences.accent) {
                    Text("White").tag("white"); Text("Peach").tag("peach")
                    Text("Mint").tag("mint"); Text("Lavender").tag("lavender")
                }.pickerStyle(.segmented)
            } header: { Text("The words") }
            Section {
                control("Width", value: $model.preferences.width, range: 360...1000, suffix: "pt")
                control("Text opacity", value: $model.preferences.textOpacity, range: 0.25...1, percent: true)
                control("Backdrop", value: $model.preferences.backgroundOpacity, range: 0...0.9, percent: true)
                Toggle("Show song and artist", isOn: $model.preferences.showTrack)
                Toggle("Show surrounding lines", isOn: $model.preferences.contextLines)
                Toggle("Hide while paused", isOn: $model.preferences.hidePaused)
                Toggle("Show overlay", isOn: $model.preferences.visible)
            } header: { Text("Keep it quiet") }
        }.formStyle(.grouped)
    }
    private var lyrics: some View {
        Form {
            Section {
                Text("Songcrumb automatically looks up each new song, tries an exact recording first, then checks search candidates by artist, title, album and duration. Synced results are preferred. Live/remix/version labels are preserved.").font(.caption).foregroundStyle(.secondary)
                Picker("Lyrics source", selection: $model.preferences.provider) {
                    Text("Offline / local files only").tag("local")
                    Text("Automatic internet lyrics · LRCLIB").tag("lrclib")
                    Text("My licensed HTTPS provider").tag("licensed")
                }
                if model.preferences.provider != "local" {
                    Link("API client identity: Songcrumb on GitHub", destination: AppIdentity.projectURL)
                        .font(.caption)
                    Text("Requests use the public project URL. No email or lyrics account is needed.")
                        .font(.caption).foregroundStyle(.secondary)
                    if model.preferences.provider == "licensed" {
                        TextField("HTTPS endpoint", text: $model.preferences.licensedEndpoint).textFieldStyle(.roundedBorder)
                        Text("Use a backend you control under a lyrics display agreement. The response must include licenseConfirmed and attribution. Keep provider secrets on that backend. See the provider contract in README.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Automatic lookup sends song title, artist, album and duration to LRCLIB’s public API. Lyrics are community supplied; API access is not a blanket copyright licence. Use only where you have display rights. Availability and timing vary.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button("Refresh this song") { model.clearSessionCache() }.disabled(model.retryAt != nil)
                Text(model.lyricsStatus).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            } header: { Text("Find the words") }
            Section {
                DisclosureGroup("Optional local override") {
                    HStack {
                        Button("Import LRC / text for this song…") { model.importLyrics() }.disabled(model.playback == nil || model.demo)
                        Button("Remove local lyrics") { model.removeLocalLyrics() }.disabled(model.playback == nil || model.demo)
                    }
                    Text("Optional override only: local files take priority. UTF-8 LRC files follow their timestamps. Plain text stays unsynced and scrolls manually. Files are copied locally and linked to this recording and source.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                HStack {
                    Text("Timing adjustment")
                    Spacer()
                    Button("−0.25 s") { model.preferences.adjustment = max(-10, model.preferences.adjustment - 0.25) }
                    Text(String(format: "%+.2f s", model.preferences.adjustment)).monospacedDigit().frame(width: 65)
                    Button("+0.25 s") { model.preferences.adjustment = min(10, model.preferences.adjustment + 0.25) }
                    Button("Reset") { model.preferences.adjustment = 0 }
                }
                Text("Positive values show lines earlier. The adjustment resets when the recording changes. Songcrumb supports line sync, not word-by-word karaoke.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
        .onChange(of: model.preferences.provider) { _, _ in model.loadLyrics() }
    }
    private var about: some View {
        Form {
            Section {
                Text("Songcrumb \(AppIdentity.version)").font(.title2.bold())
                Text("A native SwiftUI + AppKit menu bar app for Apple Silicon. macOS 14 or later. No account, telemetry, audio capture or private MediaRemote APIs.")
                Text("Local mode makes no lyrics network requests. Network lyrics remain in a small session cache. Music apps are checked about once per second while playing, every three seconds when idle, and more slowly in Low Power Mode. Work pauses when the display sleeps.")
                Text("The overlay follows normal app windows and Spaces using public NSPanel APIs. Full-screen, Stage Manager and system-owned surfaces can impose limits. It will not cover the login screen or security prompts.")
            } header: { Text("Made for the music between everything") }
            Section {
                Link("LRCLIB API documentation", destination: URL(string: "https://lrclib.net/docs")!)
                Link("Apple · Automation and Apple Events", destination: URL(string: "https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events")!)
                Text("The included preview uses original Songcrumb text. No commercial lyrics are bundled. YouTube Music integration reads only visible playback metadata and the media clock; it does not extract lyrics or media streams.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
    private func control(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String = "", percent: Bool = false) -> some View {
        HStack {
            Text(title).frame(width: 115, alignment: .leading)
            Slider(value: value, in: range)
            Text(percent ? "\(Int(value.wrappedValue * 100))%" : "\(Int(value.wrappedValue)) \(suffix)")
                .monospacedDigit().foregroundStyle(.secondary).frame(width: 58, alignment: .trailing)
        }
    }
}

struct MenuView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "quote.bubble.fill").foregroundStyle(model.preferences.tint)
                Text("Songcrumb").font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                Text(model.demo ? "PREVIEW" : "LYRICS, IN YOUR SPACE").font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(model.playback?.title ?? "Nothing playing yet").font(.headline).lineLimit(2)
                Text(model.playback.map { "\($0.artist) · \($0.source.name)" } ?? "Connect your music in Settings")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Divider()
            Toggle("Show lyrics overlay", isOn: $model.preferences.visible)
            Button { model.editing.toggle() } label: {
                Label(model.editing ? "Lock overlay · click through" : "Unlock overlay controls", systemImage: model.editing ? "lock" : "hand.draw")
            }
            Picker("Position", selection: Binding(get: { model.preferences.placement ?? "top" }, set: { model.preferences.placement = $0 })) {
                Text("Attached below menu bar").tag("top")
                Text("Floating").tag("floating")
            }
            if model.preferences.topAttached { DisplayPicker(model: model) }
            Picker("Music", selection: $model.preferences.source) {
                Text("Automatic").tag("auto")
                ForEach([MusicSource.spotify, .appleMusic, .youtubeMusic]) { Text($0.name).tag($0.rawValue) }
            }
            HStack {
                Label("Automatic online lyrics", systemImage: "network").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(model.retryAt == nil ? "Refresh" : "Retry scheduled") { model.clearSessionCache() }.disabled(model.playback == nil || model.retryAt != nil)
            }
            Text(model.lyricsStatus).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            Divider()
            HStack {
                Button("Settings…") { model.showSettings?() }
                Spacer()
                Button(model.demo ? "End preview" : "Preview") { model.toggleDemo() }
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .buttonStyle(.plain)
        .padding(20).frame(width: 340)
        .tint(model.preferences.tint)
        .preferredColorScheme(.dark)
    }
}

struct DisplayPicker: View {
    @ObservedObject var model: AppModel
    private var selected: Binding<String> {
        Binding(get: { model.preferences.attachedDisplayID ?? "automatic" }, set: { model.preferences.attachedDisplayID = $0 == "automatic" ? nil : $0 })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Picker("Display", selection: selected) {
                Text("Main display").tag("automatic")
                ForEach(model.displays) { display in
                    Text("\(display.name) · \(display.detail)").tag(display.id)
                }
                if let id = model.preferences.attachedDisplayID, !model.displays.contains(where: { $0.id == id }) {
                    Text("Disconnected display").tag(id)
                }
            }
            if let id = model.preferences.attachedDisplayID, !model.displays.contains(where: { $0.id == id }) {
                Text("Using the main display until your chosen monitor reconnects.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

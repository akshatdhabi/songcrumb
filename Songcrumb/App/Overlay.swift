import AppKit
import SwiftUI
import Combine

final class LyricsPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // AppKit's default constraint reserves the menu bar above ordinary windows.
    // This borderless panel supplies its own display bounds and safe text inset.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

@MainActor final class OverlayController: NSObject, NSWindowDelegate {
    private let model: AppModel
    let panel: LyricsPanel
    private var subscription: AnyCancellable?
    private var screenObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private var wasAttached: Bool?
    private var placingWindow = false
    init(model: AppModel) {
        self.model = model
        panel = LyricsPanel(contentRect: NSRect(x: 0, y: 0, width: 640, height: 300),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.isOpaque = false; panel.backgroundColor = .clear
        panel.title = "Songcrumb Lyrics"
        panel.hasShadow = false; panel.level = .floating
        panel.hidesOnDeactivate = false; panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: OverlayView(model: model))
        // Floating coordinates are separate from the selected attached monitor.
        // Never replace a saved display choice with the pointer's screen at launch.
        if !model.preferences.topAttached {
            if let stored = UserDefaults.standard.string(forKey: "overlayFrame") {
                let frame = NSRectFromString(stored)
                if frame.origin.x.isFinite, frame.origin.y.isFinite { panel.setFrameOrigin(frame.origin) }
                else { resetPosition() }
            } else { resetPosition() }
        }
        // A removed external display must not leave a same-sized saved window off-screen.
        fitToScreen()
        model.panelChanged = { [weak self] in self?.refresh() }
        subscription = model.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.refresh() }
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh(); self?.fitToScreen() }
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }
    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
    }
    func refresh() {
        let attached = model.preferences.topAttached
        if wasAttached != attached {
            if wasAttached == false { saveFrame() }
            wasAttached = attached
            if !attached, let stored = UserDefaults.standard.string(forKey: "overlayFrame") {
                let origin = NSRectFromString(stored).origin
                if origin.x.isFinite, origin.y.isFinite { panel.setFrameOrigin(origin) }
            }
        }
        panel.ignoresMouseEvents = !model.editing
        panel.isMovableByWindowBackground = model.editing && !attached
        let height: Double
        if attached {
            height = model.preferences.contextLines ? max(136, model.preferences.fontSize * 4 + 52) : max(104, model.preferences.fontSize * 2 + 52)
        } else {
            height = model.preferences.contextLines ? max(280, model.preferences.fontSize * 9.5) : max(200, model.preferences.fontSize * 6)
        }
        let screen = attached ? attachedScreen() : (panel.screen ?? NSScreen.main)
        let size = NSSize(width: min(model.preferences.width, (screen?.visibleFrame.width ?? 1200) - 24), height: min(height, (screen?.visibleFrame.height ?? 800) - 24))
        if attached, let screen {
            let layout = OverlayGeometry.attachedLayout(screen: screen.frame, visible: screen.visibleFrame,
                safeTop: screen.safeAreaInsets.top,
                menuBarHeight: max(NSStatusBar.system.thickness, screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top + 1 : 0),
                requestedSize: size)
            if model.overlayTopInset != layout.topInset { model.overlayTopInset = layout.topInset }
            let frame = layout.frame
            if panel.frame != frame {
                placingWindow = true; panel.setFrame(frame, display: true); placingWindow = false
            }
        } else {
            if model.overlayTopInset != 0 { model.overlayTopInset = 0 }
            if panel.frame.size != size { panel.setContentSize(size); fitToScreen() }
        }
        let visible = !model.suspended && model.preferences.visible &&
            (model.editing || model.demo || (model.playback != nil && (!model.preferences.hidePaused || model.playback?.playing == true)))
        if visible && !panel.isVisible { panel.orderFrontRegardless() }
        else if !visible && panel.isVisible { panel.orderOut(nil) }
    }
    private func attachedScreen() -> NSScreen? {
        if model.preferences.attachedDisplayID == nil,
           let saved = UserDefaults.standard.object(forKey: "attachedDisplay") as? NSNumber,
           let legacy = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber) == saved }) {
            model.preferences.attachedDisplayID = DisplayCatalog.identifier(for: legacy)
            UserDefaults.standard.removeObject(forKey: "attachedDisplay")
        }
        return DisplayCatalog.screen(preferred: model.preferences.attachedDisplayID)
    }
    func resetPosition() {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }
        if model.preferences.topAttached {
            model.preferences.attachedDisplayID = DisplayCatalog.identifier(for: screen)
            refresh()
        } else {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.minY + 90))
            saveFrame()
        }
    }
    private func fitToScreen() {
        if model.preferences.topAttached { refresh(); return }
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let screen = screens.max { a, b in
            let ia = a.visibleFrame.intersection(panel.frame), ib = b.visibleFrame.intersection(panel.frame)
            return ia.width * ia.height < ib.width * ib.height
        } ?? screens[0]
        let bounds = screen.visibleFrame
        var origin = panel.frame.origin
        origin.x = max(bounds.minX + 8, min(origin.x, bounds.maxX - panel.frame.width - 8))
        origin.y = max(bounds.minY + 8, min(origin.y, bounds.maxY - panel.frame.height - 8))
        panel.setFrameOrigin(origin); saveFrame()
    }
    private func saveFrame() {
        guard !model.preferences.topAttached else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "overlayFrame")
    }
    func windowDidMove(_ notification: Notification) {
        guard !placingWindow else { return }
        if model.preferences.topAttached { refresh() } else { saveFrame() }
    }

}

struct OverlayView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: model.preferences.topAttached ? 5 : 12) {
            if model.preferences.topAttached { compactHeader }
            if model.editing && !model.preferences.topAttached {
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                    Text("Drag the edges to move · scroll plain lyrics here")
                    Spacer()
                    Button("Done") { model.editing = false }.buttonStyle(.plain).fontWeight(.semibold)
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 8)
            }
            if !model.preferences.topAttached, model.preferences.showTrack, let track = model.playback {
                HStack(spacing: 8) {
                    Image(systemName: track.playing ? "waveform" : "pause.fill").foregroundStyle(model.preferences.tint)
                    Text(track.title).fontWeight(.semibold).lineLimit(1)
                    Text("·").foregroundStyle(.white.opacity(0.35))
                    Text(track.artist).lineLimit(1).foregroundStyle(.white.opacity(0.6))
                    Spacer(minLength: 0)
                    Text(track.source == .demo ? "PREVIEW" : track.source.name.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .font(.system(size: 12)).padding(.horizontal, 10)
            }
            if let doc = model.lyrics {
                if doc.instrumental {
                    emptyState(icon: "music.quarternote.3", title: "Just the music.", subtitle: "This recording is marked instrumental.")
                } else if doc.synced {
                    TimelineView(.animation(minimumInterval: model.lowPower ? 0.5 : 0.2,
                                            paused: model.playback?.playing != true || !model.preferences.visible || model.suspended)) { _ in
                        let position = model.playback?.position(at: ProcessInfo.processInfo.systemUptime) ?? 0
                        SyncedLyricsView(document: doc, active: doc.activeIndex(at: position, adjustment: model.preferences.adjustment), preferences: model.preferences)
                            .id(model.playback?.key)
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("UNSYNCED · \(model.editing ? "SCROLL TO READ" : "UNLOCK IN MENU BAR TO SCROLL")")
                            .font(.system(size: 9, weight: .semibold)).tracking(1.3).foregroundStyle(model.preferences.tint)
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(doc.plain).font(.system(size: model.preferences.fontSize, weight: .regular, design: model.preferences.lyricFontDesign))
                                .lineSpacing(10).frame(maxWidth: .infinity, alignment: .leading).textSelection(.disabled)
                        }.scrollIndicators(.hidden)
                    }.padding(.horizontal, 12)
                }
                Text(doc.attribution).font(.system(size: model.preferences.topAttached ? 8 : 9)).foregroundStyle(.white.opacity(0.4)).lineLimit(2)
            } else {
                emptyState(icon: model.retryAt != nil ? "clock" : (model.loading ? "ellipsis" : "text.quote"),
                    title: model.retryAt != nil ? "Waiting for the words…" : (model.loading ? "Finding the words…" : "A little room for music."), subtitle: model.lyricsStatus)
            }
        }
        .padding(model.preferences.topAttached ? 12 : 22)
        .padding(.top, model.overlayTopInset)
        .foregroundStyle(.white)
        .opacity(model.preferences.textOpacity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: model.preferences.topAttached ? 0 : 26,
                                   bottomLeadingRadius: model.preferences.topAttached ? 20 : 26,
                                   bottomTrailingRadius: model.preferences.topAttached ? 20 : 26,
                                   topTrailingRadius: model.preferences.topAttached ? 0 : 26)
                .fill(Color.black.opacity(model.preferences.backgroundOpacity))
                .overlay {
                    UnevenRoundedRectangle(topLeadingRadius: model.preferences.topAttached ? 0 : 26,
                                           bottomLeadingRadius: model.preferences.topAttached ? 20 : 26,
                                           bottomTrailingRadius: model.preferences.topAttached ? 20 : 26,
                                           topTrailingRadius: model.preferences.topAttached ? 0 : 26)
                        .strokeBorder(.white.opacity(model.editing ? 0.3 : 0.08), lineWidth: 1)
                }
        }
        .padding(model.preferences.topAttached ? 0 : 6)
        .preferredColorScheme(.dark)
    }
    private var compactHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.quote").foregroundStyle(Color(red: 1, green: 0.76, blue: 0.61))
            if model.preferences.showTrack {
                Text(model.playback.map { "\($0.title) · \($0.artist)" } ?? "Songcrumb")
                    .lineLimit(1).foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 4)
            if model.editing {
                Button { model.preferences.placement = "floating" } label: { Image(systemName: "rectangle.portrait.and.arrow.right") }
                    .help("Switch to floating overlay").accessibilityLabel("Switch to floating overlay")
                Button { model.showSettings?() } label: { Image(systemName: "slider.horizontal.3") }
                    .help("Appearance and music sources").accessibilityLabel("Open Songcrumb settings")
                Button("Lock") { model.editing = false }.fontWeight(.semibold)
            } else {
                Image(systemName: "lock.fill").foregroundStyle(.white.opacity(0.3))
                    .accessibilityLabel("Click through enabled; unlock in Songcrumb menu")
            }
        }
        .font(.system(size: 10, weight: .medium))
        .buttonStyle(.plain)
        .padding(.horizontal, 6).padding(.bottom, 2)
    }
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: model.preferences.topAttached ? 5 : 13) {
            Image(systemName: icon).font(.system(size: model.preferences.topAttached ? 15 : 25, weight: .light)).foregroundStyle(model.preferences.tint)
            Text(title).font(.system(size: min(30, model.preferences.fontSize), weight: .semibold, design: .rounded))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center).lineLimit(model.preferences.topAttached ? 2 : 4)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(14)
    }
}

struct SyncedLyricsView: View {
    let document: LyricsDocument
    let active: Int?
    let preferences: Preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: preferences.topAttached ? 7 : 16) {
                        if active == nil {
                            Text("Waiting for the first line…")
                                .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.5)).id(-1)
                        }
                        ForEach(document.lines) { line in
                            Text(line.text)
                                .font(.system(size: preferences.fontSize, weight: preferences.topAttached ? (active == line.id ? .medium : .regular) : (active == line.id ? .bold : .medium), design: preferences.lyricFontDesign))
                                .foregroundStyle(active == line.id ? preferences.tint : .white.opacity(preferences.contextLines ? 0.33 : 0))
                                .shadow(color: .black.opacity(0.4), radius: preferences.topAttached ? 0 : 4, y: preferences.topAttached ? 0 : 2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                    }
                    .padding(.vertical, geometry.size.height / 2)
                    .padding(.horizontal, 12)
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(true)
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18), .init(color: .black, location: 0.82), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                .onAppear { proxy.scrollTo(active ?? -1, anchor: .center) }
                .onChange(of: active) { old, new in
                    // Long seeks jump directly; normal line changes glide into place.
                    let animate = !reduceMotion && abs((new ?? 0) - (old ?? 0)) <= 2
                    withAnimation(animate ? .easeInOut(duration: 0.45) : nil) { proxy.scrollTo(new ?? -1, anchor: .center) }
                }
                .onChange(of: preferences.fontSize) { _, _ in proxy.scrollTo(active ?? -1, anchor: .center) }
                .onChange(of: preferences.width) { _, _ in proxy.scrollTo(active ?? -1, anchor: .center) }
                .onChange(of: preferences.typeface) { _, _ in proxy.scrollTo(active ?? -1, anchor: .center) }
                .onChange(of: preferences.placement) { _, _ in proxy.scrollTo(active ?? -1, anchor: .center) }
                .onChange(of: preferences.contextLines) { _, _ in proxy.scrollTo(active ?? -1, anchor: .center) }
            }
        }
    }
}

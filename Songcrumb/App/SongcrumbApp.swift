import AppKit
import SwiftUI

@main struct SongcrumbApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        MenuBarExtra {
            MenuView(model: delegate.model)
        } label: {
            Image(systemName: "text.quote").accessibilityLabel("Songcrumb lyrics")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var overlay: OverlayController?
    private var settings: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        overlay = OverlayController(model: model)
        model.showSettings = { [weak self] in self?.openSettings() }
        if CommandLine.arguments.contains("--demo") { model.toggleDemo() }
        let firstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunched")
        if firstLaunch || CommandLine.arguments.contains("--settings") { openSettings() }
        UserDefaults.standard.set(true, forKey: "hasLaunched")
    }
    func openSettings() {
        if settings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 700),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Songcrumb Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(model: model, resetPosition: { [weak self] in self?.overlay?.resetPosition() }))
            window.center(); settings = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model.shutdown() }
}

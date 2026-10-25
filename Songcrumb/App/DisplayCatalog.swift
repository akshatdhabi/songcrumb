import AppKit

struct OverlayDisplay: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
}

@MainActor enum DisplayCatalog {
    static func identifier(for screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
    static var connected: [OverlayDisplay] {
        NSScreen.screens.enumerated().compactMap { index, screen in
            guard let id = identifier(for: screen) else { return nil }
            let size = "\(Int(screen.frame.width)) × \(Int(screen.frame.height))"
            return OverlayDisplay(id: id, name: screen.localizedName, detail: "\(index == 0 ? "Main display · " : "")\(size)")
        }
    }
    static func screen(preferred id: String?) -> NSScreen? {
        NSScreen.screens.first { identifier(for: $0) == id } ?? NSScreen.screens.first
    }
}

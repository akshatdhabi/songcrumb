import Foundation
import CoreGraphics

/// AppKit's visible screen frame already excludes the menu bar and Dock.
/// Keeping this calculation independent of NSWindow makes display changes testable.
enum OverlayGeometry {
    static func attachedFrame(in visibleFrame: CGRect, requestedSize: CGSize) -> CGRect {
        let width = min(max(1, requestedSize.width), max(1, visibleFrame.width - 16))
        let height = min(max(1, requestedSize.height), max(1, visibleFrame.height - 16))
        return CGRect(x: visibleFrame.midX - width / 2, y: visibleFrame.maxY - height,
                      width: width, height: height)
    }
}

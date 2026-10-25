import Foundation
import CoreGraphics

/// Display geometry in AppKit coordinates, independent of the active Space.
/// Keeping this calculation independent of NSWindow makes display changes testable.
enum OverlayGeometry {
    /// Always attach the backdrop to the physical edge. Menu-bar and camera
    /// clearance belongs inside the panel, so auto-hiding never leaves a gap.
    static func attachedLayout(screen: CGRect, visible: CGRect, safeTop: CGFloat,
                               menuBarHeight: CGFloat, requestedSize: CGSize) -> (frame: CGRect, topInset: CGFloat) {
        let inset = max(0, max(safeTop, menuBarHeight))
        let bounds = CGRect(x: screen.minX, y: visible.minY, width: screen.width,
                            height: max(1, screen.maxY - visible.minY))
        return (attachedFrame(in: bounds, requestedSize: CGSize(width: requestedSize.width,
                                                               height: requestedSize.height + inset)), inset)
    }
    static func attachedFrame(in visibleFrame: CGRect, requestedSize: CGSize) -> CGRect {
        let width = min(max(1, requestedSize.width), max(1, visibleFrame.width - 16))
        let height = min(max(1, requestedSize.height), max(1, visibleFrame.height - 16))
        return CGRect(x: visibleFrame.midX - width / 2, y: visibleFrame.maxY - height,
                      width: width, height: height)
    }
}

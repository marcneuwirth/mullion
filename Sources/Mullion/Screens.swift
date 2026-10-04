#if os(macOS)
import AppKit
import MullionCore

/// Usable screen areas (menu bar and Dock excluded) in Accessibility coordinates.
enum Screens {
    @MainActor
    static func visibleFrames() -> [Frame] {
        // Cocoa puts the origin at the bottom-left of the primary screen; Accessibility uses its top-left.
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return [] }
        return NSScreen.screens.map { screen in
            let f = screen.visibleFrame
            return Frame(x: f.minX, y: primaryHeight - f.maxY, w: f.width, h: f.height)
        }
    }
}
#endif

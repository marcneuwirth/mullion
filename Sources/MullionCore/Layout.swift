import Foundation

/// A rectangle in Accessibility coordinates: origin at the top-left of the primary display, y grows downward.
public struct Frame: Equatable, CustomStringConvertible {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    public var maxX: Double { x + w }
    public var maxY: Double { y + h }

    public func intersectionArea(_ other: Frame) -> Double {
        let iw = min(maxX, other.maxX) - max(x, other.x)
        let ih = min(maxY, other.maxY) - max(y, other.y)
        return iw > 0 && ih > 0 ? iw * ih : 0
    }

    /// Within 2pt on every edge, since apps round the frames they are given.
    public func isClose(to other: Frame) -> Bool {
        abs(x - other.x) <= 2 && abs(y - other.y) <= 2 && abs(w - other.w) <= 2 && abs(h - other.h) <= 2
    }

    public var description: String { "(\(x), \(y), \(w)x\(h))" }
}

public enum Layout {
    /// The window frame for `cells` on a screen whose usable area is `screen`.
    ///
    /// Cell edges are rounded to whole points from the same formula, so neighbouring cells share an
    /// edge exactly (no 1pt seams on odd widths). `gap` is applied at screen edges and between windows.
    public static func frame(for cells: Cells, grid: Grid, in screen: Frame, gap: Double = 0) -> Frame {
        func edge(_ i: Int, of count: Int, from origin: Double, span: Double) -> Double {
            origin + (span * Double(i) / Double(count)).rounded()
        }
        let half = gap / 2
        let left = edge(cells.x, of: grid.columns, from: screen.x, span: screen.w)
            + (cells.x == 0 ? gap : half)
        let right = edge(cells.x + cells.w, of: grid.columns, from: screen.x, span: screen.w)
            - (cells.x + cells.w == grid.columns ? gap : half)
        let top = edge(cells.y, of: grid.rows, from: screen.y, span: screen.h)
            + (cells.y == 0 ? gap : half)
        let bottom = edge(cells.y + cells.h, of: grid.rows, from: screen.y, span: screen.h)
            - (cells.y + cells.h == grid.rows ? gap : half)
        return Frame(x: left, y: top, w: max(1, right - left), h: max(1, bottom - top))
    }

    /// Screens ordered left to right (then top to bottom), which is the order shortcuts cycle through.
    public static func cycleOrder(_ screens: [Frame]) -> [Frame] {
        screens.sorted { ($0.x, $0.y) < ($1.x, $1.y) }
    }

    /// Index of the screen that holds most of `window`; 0 if it is entirely off-screen.
    public static func screenIndex(for window: Frame, in screens: [Frame]) -> Int {
        var best = 0
        var bestArea = -1.0
        for (i, screen) in screens.enumerated() {
            let area = window.intersectionArea(screen)
            if area > bestArea {
                best = i
                bestArea = area
            }
        }
        return best
    }

    /// Divvy's "cycle between screens": pressing a shortcut again moves the window on to the next screen.
    ///
    /// Repeat is detected two ways: the window already sits at the target frame, or it is exactly where
    /// this same shortcut last put it. The second case covers apps that round their size (terminals snap
    /// to whole character cells), so they never land precisely on the target.
    public static func isRepeat(current: Frame, target: Frame, last: Placement?, shortcut: Shortcut) -> Bool {
        if current.isClose(to: target) { return true }
        guard let last, last.shortcut == shortcut else { return false }
        return current.isClose(to: last.frame)
    }
}

/// What the most recent shortcut did, kept to detect a repeat press.
public struct Placement: Equatable {
    public var shortcut: Shortcut
    /// The frame the window actually ended up with (read back after moving it).
    public var frame: Frame

    public init(shortcut: Shortcut, frame: Frame) {
        self.shortcut = shortcut
        self.frame = frame
    }
}

extension Config {
    /// Where `shortcut` sends a window that is now at `window`: its cells on the screen holding most of the
    /// window, or on the next screen if this press is a repeat and `cycleScreens` is on. `last` is what the
    /// previous shortcut did to this same window. Nil when there are no screens.
    public func target(for shortcut: Shortcut, window: Frame, screens: [Frame], last: Placement?) -> Frame? {
        let screens = Layout.cycleOrder(screens)
        guard !screens.isEmpty else { return nil }
        let screen = Layout.screenIndex(for: window, in: screens)
        let target = frame(for: shortcut.cells, on: screens[screen])
        guard cycleScreens, screens.count > 1,
              Layout.isRepeat(current: window, target: target, last: last, shortcut: shortcut)
        else { return target }
        return frame(for: shortcut.cells, on: screens[(screen + 1) % screens.count])
    }

    private func frame(for cells: Cells, on screen: Frame) -> Frame {
        Layout.frame(for: cells, grid: grid, in: screen, gap: gap)
    }
}

import XCTest
@testable import MullionCore

final class ConfigTests: XCTestCase {
    func testDefaultConfigParses() throws {
        let config = try Config.parse(Data(Config.defaultJSON.utf8))
        XCTAssertEqual(config.shortcuts.count, 8)
        XCTAssertEqual(config.shortcuts[0].combo, KeyCombo(keyCode: 0x7B, modifiers: Modifier.control | Modifier.cmd))
    }

    func testOmittedSettingsMatchTheDefaultFile() throws {
        let written = try Config.parse(Data(Config.defaultJSON.utf8))
        let omitted = try Config.parse(Data("{}".utf8))
        XCTAssertEqual(omitted.grid, written.grid)
        XCTAssertEqual(omitted.gap, written.gap)
        XCTAssertEqual(omitted.cycleScreens, written.cycleScreens)
        XCTAssertEqual(omitted.shortcuts, [])
    }

    func testReadmeShowsTheDefaultFile() throws {
        let readme = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("README.md")
        let text = try String(contentsOf: readme, encoding: .utf8)
        XCTAssertTrue(text.contains("```json\n\(Config.defaultJSON)```"), "README's config example differs from Config.defaultJSON")
    }

    func testUnknownKeysAreRejected() {
        let cases = [
            (#"{"cycleScreen": false}"#, #"unknown key "cycleScreen""#),
            (#"{"grid": {"columns": 4, "row": 4}}"#, #"unknown key "row" at .grid"#),
            (#"{"shortcuts": [{"keys": "ctrl+a", "cell": {"x": 0, "y": 0, "w": 1, "h": 1}}]}"#, #"unknown key "cell" at .shortcuts[0]"#),
            (#"{"shortcuts": [{"keys": "ctrl+a", "cells": {"x": 0, "y": 0, "w": 1, "h": 1, "width": 2}}]}"#,
             #"unknown key "width" at .shortcuts[0].cells"#),
        ]
        for (json, message) in cases {
            XCTAssertThrowsError(try Config.parse(Data(json.utf8)), json) { error in
                XCTAssertEqual("\(error)", "config error: \(message)")
            }
        }
    }

    func testCellsOutsideGridAreRejected() {
        let json = #"{"grid": {"columns": 4, "rows": 4}, "shortcuts": [{"keys": "ctrl+a", "cells": {"x": 2, "y": 0, "w": 3, "h": 1}}]}"#
        XCTAssertThrowsError(try Config.parse(Data(json.utf8))) { error in
            XCTAssertTrue("\(error)".contains("ctrl+a"), "\(error)")
        }
    }

    func testDuplicateShortcutsAreRejected() {
        let json = #"{"shortcuts": [{"keys": "ctrl+cmd+left", "cells": {"x": 0, "y": 0, "w": 1, "h": 1}}, {"keys": "cmd+ctrl+left", "cells": {"x": 1, "y": 0, "w": 1, "h": 1}}]}"#
        XCTAssertThrowsError(try Config.parse(Data(json.utf8)))
    }

    func testMalformedJSONIsReported() {
        XCTAssertThrowsError(try Config.parse(Data("{".utf8))) { error in
            guard case ConfigError.invalidJSON = error else { return XCTFail("\(error)") }
        }
    }

    func testMissingCellsNamesThePath() {
        let json = #"{"shortcuts": [{"keys": "ctrl+a"}]}"#
        XCTAssertThrowsError(try Config.parse(Data(json.utf8))) { error in
            XCTAssertTrue("\(error)".contains("cells"), "\(error)")
        }
    }
}

final class KeyComboTests: XCTestCase {
    func testParsesModifiersInAnyOrderAndCase() throws {
        let a = try KeyCombo(parsing: "ctrl+cmd+PageDown")
        let b = try KeyCombo(parsing: "Command + Control + pagedown")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.keyCode, 0x79)
        XCTAssertEqual(a.modifiers, Modifier.control | Modifier.cmd)
    }

    func testNavigationAndFunctionKeys() throws {
        XCTAssertEqual(try KeyCombo(parsing: "ctrl+home").keyCode, 0x73)
        XCTAssertEqual(try KeyCombo(parsing: "ctrl+end").keyCode, 0x77)
        XCTAssertEqual(try KeyCombo(parsing: "ctrl+pageup").keyCode, 0x74)
        XCTAssertEqual(try KeyCombo(parsing: "ctrl+f1").keyCode, 0x7A)
        XCTAssertEqual(try KeyCombo(parsing: "ctrl+f12").keyCode, 0x6F)
    }

    func testRejectsBadInput() {
        XCTAssertThrowsError(try KeyCombo(parsing: "left"))            // no modifier
        XCTAssertThrowsError(try KeyCombo(parsing: "hyper+left"))      // unknown modifier
        XCTAssertThrowsError(try KeyCombo(parsing: "ctrl+banana"))     // unknown key
        XCTAssertThrowsError(try KeyCombo(parsing: "ctrl+ctrl+left"))  // repeated modifier
        XCTAssertThrowsError(try KeyCombo(parsing: "ctrl+"))           // missing key
    }
}

final class LayoutTests: XCTestCase {
    let grid = Grid(columns: 6, rows: 6)
    // A 1512x945 visible area below a 37pt menu bar, like a 14" MacBook Pro.
    let screen = Frame(x: 0, y: 37, w: 1512, h: 945)

    func testHalvesAndFull() {
        XCTAssertEqual(Layout.frame(for: Cells(x: 0, y: 0, w: 3, h: 6), grid: grid, in: screen),
                       Frame(x: 0, y: 37, w: 756, h: 945))
        XCTAssertEqual(Layout.frame(for: Cells(x: 3, y: 0, w: 3, h: 6), grid: grid, in: screen),
                       Frame(x: 756, y: 37, w: 756, h: 945))
        XCTAssertEqual(Layout.frame(for: Cells(x: 0, y: 0, w: 6, h: 6), grid: grid, in: screen), screen)
    }

    func testQuartersTileWithoutSeamsOnOddSizes() {
        let odd = Frame(x: 0, y: 25, w: 1441, h: 875)
        let topLeft = Layout.frame(for: Cells(x: 0, y: 0, w: 3, h: 3), grid: grid, in: odd)
        let bottomRight = Layout.frame(for: Cells(x: 3, y: 3, w: 3, h: 3), grid: grid, in: odd)
        XCTAssertEqual(topLeft.maxX, bottomRight.x)
        XCTAssertEqual(topLeft.maxY, bottomRight.y)
        XCTAssertEqual(bottomRight.maxX, odd.maxX)
        XCTAssertEqual(bottomRight.maxY, odd.maxY)
    }

    func testGapAtEdgesAndBetweenWindows() {
        let left = Layout.frame(for: Cells(x: 0, y: 0, w: 3, h: 6), grid: grid, in: screen, gap: 10)
        let right = Layout.frame(for: Cells(x: 3, y: 0, w: 3, h: 6), grid: grid, in: screen, gap: 10)
        XCTAssertEqual(left, Frame(x: 10, y: 47, w: 741, h: 925))
        XCTAssertEqual(right.x - left.maxX, 10)
        XCTAssertEqual(screen.maxX - right.maxX, 10)
    }

    func testSecondScreenOffset() {
        let external = Frame(x: 1512, y: -300, w: 2560, h: 1415)
        XCTAssertEqual(Layout.frame(for: Cells(x: 3, y: 0, w: 3, h: 6), grid: grid, in: external),
                       Frame(x: 2792, y: -300, w: 1280, h: 1415))
    }

    func testScreenIndexPicksLargestOverlap() {
        let screens = [Frame(x: 0, y: 0, w: 1000, h: 800), Frame(x: 1000, y: 0, w: 1000, h: 800)]
        XCTAssertEqual(Layout.screenIndex(for: Frame(x: 900, y: 0, w: 300, h: 300), in: screens), 1)
        XCTAssertEqual(Layout.screenIndex(for: Frame(x: 100, y: 0, w: 300, h: 300), in: screens), 0)
        XCTAssertEqual(Layout.screenIndex(for: Frame(x: 5000, y: 0, w: 10, h: 10), in: screens), 0)
    }

    func testCycleOrderIsLeftToRight() {
        let laptop = Frame(x: 0, y: 0, w: 1512, h: 945)
        let leftMonitor = Frame(x: -2560, y: -400, w: 2560, h: 1415)
        XCTAssertEqual(Layout.cycleOrder([laptop, leftMonitor]), [leftMonitor, laptop])
    }

    func testRepeatDetection() throws {
        let target = Frame(x: 0, y: 37, w: 756, h: 945)
        let snapped = Frame(x: 0, y: 37, w: 749, h: 940)  // a terminal rounding to whole character cells
        let left = try shortcut("ctrl+left", Cells(x: 0, y: 0, w: 3, h: 6))
        let right = try shortcut("ctrl+right", Cells(x: 3, y: 0, w: 3, h: 6))

        XCTAssertTrue(Layout.isRepeat(current: target, target: target, last: nil, shortcut: left))
        XCTAssertFalse(Layout.isRepeat(current: snapped, target: target, last: nil, shortcut: left))
        XCTAssertTrue(Layout.isRepeat(current: snapped, target: target,
                                      last: Placement(shortcut: left, frame: snapped), shortcut: left))
        XCTAssertFalse(Layout.isRepeat(current: snapped, target: target,
                                       last: Placement(shortcut: right, frame: snapped), shortcut: left))
    }
}

final class TargetTests: XCTestCase {
    // Listed out of order: cycling goes left to right regardless.
    let laptop = Frame(x: 0, y: 0, w: 1200, h: 800)
    let external = Frame(x: 1200, y: 0, w: 1200, h: 800)
    let leftHalf = Cells(x: 0, y: 0, w: 3, h: 6)
    var screens: [Frame] { [external, laptop] }

    func config(cycleScreens: Bool = true) throws -> Config {
        var config = try Config.parse(Data("{}".utf8))
        config.cycleScreens = cycleScreens
        return config
    }

    func testFirstPressStaysOnTheWindowsScreen() throws {
        let left = try shortcut("ctrl+left", leftHalf)
        let window = Frame(x: 1500, y: 100, w: 400, h: 300)
        XCTAssertEqual(try config().target(for: left, window: window, screens: screens, last: nil),
                       Frame(x: 1200, y: 0, w: 600, h: 800))
    }

    func testRepeatPressMovesToTheNextScreenAndWraps() throws {
        let left = try shortcut("ctrl+left", leftHalf)
        let onLaptop = Frame(x: 0, y: 0, w: 600, h: 800)
        let onExternal = Frame(x: 1200, y: 0, w: 600, h: 800)
        XCTAssertEqual(try config().target(for: left, window: onLaptop, screens: screens, last: nil), onExternal)
        XCTAssertEqual(try config().target(for: left, window: onExternal, screens: screens, last: nil), onLaptop)
    }

    func testRepeatUsesWhereTheSameShortcutLeftTheWindow() throws {
        let left = try shortcut("ctrl+left", leftHalf)
        let snapped = Frame(x: 0, y: 0, w: 593, h: 790)
        XCTAssertEqual(try config().target(for: left, window: snapped, screens: screens,
                                           last: Placement(shortcut: left, frame: snapped)),
                       Frame(x: 1200, y: 0, w: 600, h: 800))
    }

    func testNoCyclingWhenTurnedOffOrOnOneScreen() throws {
        let left = try shortcut("ctrl+left", leftHalf)
        let onLaptop = Frame(x: 0, y: 0, w: 600, h: 800)
        XCTAssertEqual(try config(cycleScreens: false).target(for: left, window: onLaptop, screens: screens, last: nil),
                       onLaptop)
        XCTAssertEqual(try config().target(for: left, window: onLaptop, screens: [laptop], last: nil), onLaptop)
    }

    func testNoScreens() throws {
        let left = try shortcut("ctrl+left", leftHalf)
        XCTAssertNil(try config().target(for: left, window: laptop, screens: [], last: nil))
    }
}

private func shortcut(_ keys: String, _ cells: Cells) throws -> Shortcut {
    Shortcut(keys: keys, combo: try KeyCombo(parsing: keys), cells: cells)
}

import Foundation

public struct Grid: Decodable, Equatable {
    public var columns: Int
    public var rows: Int

    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }

    private enum CodingKeys: String, CodingKey, CaseIterable { case columns, rows }

    public init(from decoder: Decoder) throws {
        try decoder.rejectKeys(notIn: CodingKeys.self)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(columns: try c.decode(Int.self, forKey: .columns), rows: try c.decode(Int.self, forKey: .rows))
    }
}

/// A rectangle of grid cells. `x`/`y` are zero-based from the top-left; `w`/`h` are in cells.
public struct Cells: Decodable, Equatable {
    public var x: Int
    public var y: Int
    public var w: Int
    public var h: Int

    public init(x: Int, y: Int, w: Int, h: Int) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    private enum CodingKeys: String, CodingKey, CaseIterable { case x, y, w, h }

    public init(from decoder: Decoder) throws {
        try decoder.rejectKeys(notIn: CodingKeys.self)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try c.decode(Int.self, forKey: .x), y: try c.decode(Int.self, forKey: .y),
                  w: try c.decode(Int.self, forKey: .w), h: try c.decode(Int.self, forKey: .h))
    }
}

public struct Shortcut: Equatable {
    public var keys: String
    public var combo: KeyCombo
    public var cells: Cells
}

public struct Config: Equatable {
    public var grid: Grid
    public var gap: Double
    public var cycleScreens: Bool
    public var shortcuts: [Shortcut]

    /// Used for any setting the file leaves out. `defaultJSON` spells out the same values, which a test checks.
    static let defaultGrid = Grid(columns: 6, rows: 6)
    static let defaultGap = 0.0
    static let defaultCycleScreens = true

    /// Decodes and validates a config file. Errors name the offending shortcut so they are easy to fix.
    public static func parse(_ data: Data) throws -> Config {
        let raw: RawConfig
        do {
            raw = try JSONDecoder().decode(RawConfig.self, from: data)
        } catch let error as DecodingError {
            throw ConfigError.invalidJSON(describe(error))
        }

        let grid = raw.grid ?? defaultGrid
        guard grid.columns > 0, grid.rows > 0 else {
            throw ConfigError.invalid("grid columns and rows must be at least 1")
        }
        let gap = raw.gap ?? defaultGap
        guard gap >= 0 else { throw ConfigError.invalid("gap must not be negative") }

        var seen: [KeyCombo: String] = [:]
        var shortcuts: [Shortcut] = []
        for entry in raw.shortcuts ?? [] {
            let combo: KeyCombo
            do {
                combo = try KeyCombo(parsing: entry.keys)
            } catch let error as KeyComboError {
                throw ConfigError.invalid("\"\(entry.keys)\": \(error.message)")
            }
            if let other = seen[combo] {
                throw ConfigError.invalid("\"\(entry.keys)\" is the same shortcut as \"\(other)\"")
            }
            seen[combo] = entry.keys

            let c = entry.cells
            guard c.w >= 1, c.h >= 1 else {
                throw ConfigError.invalid("\"\(entry.keys)\": cells w and h must be at least 1")
            }
            guard c.x >= 0, c.y >= 0, c.x + c.w <= grid.columns, c.y + c.h <= grid.rows else {
                throw ConfigError.invalid(
                    "\"\(entry.keys)\": cells x=\(c.x) y=\(c.y) w=\(c.w) h=\(c.h) do not fit a \(grid.columns)x\(grid.rows) grid")
            }
            shortcuts.append(Shortcut(keys: entry.keys, combo: combo, cells: c))
        }

        return Config(grid: grid, gap: gap, cycleScreens: raw.cycleScreens ?? defaultCycleScreens, shortcuts: shortcuts)
    }

    /// Written to disk on first launch. Matches the original Divvy setup: 6x6 grid, halves, quarters, full screen.
    public static let defaultJSON = """
    {
      "grid": { "columns": 6, "rows": 6 },
      "gap": 0,
      "cycleScreens": true,
      "shortcuts": [
        { "keys": "ctrl+cmd+left",     "cells": { "x": 0, "y": 0, "w": 3, "h": 6 } },
        { "keys": "ctrl+cmd+right",    "cells": { "x": 3, "y": 0, "w": 3, "h": 6 } },
        { "keys": "ctrl+cmd+up",       "cells": { "x": 0, "y": 0, "w": 6, "h": 6 } },
        { "keys": "ctrl+cmd+down",     "cells": { "x": 0, "y": 3, "w": 6, "h": 3 } },
        { "keys": "ctrl+cmd+home",     "cells": { "x": 0, "y": 0, "w": 3, "h": 3 } },
        { "keys": "ctrl+cmd+pageup",   "cells": { "x": 3, "y": 0, "w": 3, "h": 3 } },
        { "keys": "ctrl+cmd+end",      "cells": { "x": 0, "y": 3, "w": 3, "h": 3 } },
        { "keys": "ctrl+cmd+pagedown", "cells": { "x": 3, "y": 3, "w": 3, "h": 3 } }
      ]
    }

    """
}

public enum ConfigError: Error, Equatable, CustomStringConvertible {
    case invalidJSON(String)
    case invalid(String)

    public var description: String {
        switch self {
        case .invalidJSON(let detail): return "config is not valid JSON: \(detail)"
        case .invalid(let detail): return "config error: \(detail)"
        }
    }
}

private struct RawConfig: Decodable {
    var grid: Grid?
    var gap: Double?
    var cycleScreens: Bool?
    var shortcuts: [RawShortcut]?

    private enum CodingKeys: String, CodingKey, CaseIterable { case grid, gap, cycleScreens, shortcuts }

    init(from decoder: Decoder) throws {
        try decoder.rejectKeys(notIn: CodingKeys.self)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grid = try c.decodeIfPresent(Grid.self, forKey: .grid)
        gap = try c.decodeIfPresent(Double.self, forKey: .gap)
        cycleScreens = try c.decodeIfPresent(Bool.self, forKey: .cycleScreens)
        shortcuts = try c.decodeIfPresent([RawShortcut].self, forKey: .shortcuts)
    }
}

private struct RawShortcut: Decodable {
    var keys: String
    var cells: Cells

    private enum CodingKeys: String, CodingKey, CaseIterable { case keys, cells }

    init(from decoder: Decoder) throws {
        try decoder.rejectKeys(notIn: CodingKeys.self)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keys = try c.decode(String.self, forKey: .keys)
        cells = try c.decode(Cells.self, forKey: .cells)
    }
}

private struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension Decoder {
    /// JSONDecoder ignores keys a type doesn't declare, which would let a typo like "cycleScreen" quietly
    /// fall back to the default. Config types call this first so that any such key is an error instead.
    fileprivate func rejectKeys<Keys: CodingKey & CaseIterable>(notIn _: Keys.Type) throws {
        let known = Set(Keys.allCases.map(\.stringValue))
        for key in try container(keyedBy: AnyKey.self).allKeys where !known.contains(key.stringValue) {
            throw ConfigError.invalid("unknown key \"\(key.stringValue)\"\(describe(codingPath))")
        }
    }
}

/// " at .shortcuts[2].cells", or "" at the top level.
private func describe(_ codingPath: [CodingKey]) -> String {
    let p = codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
    return p.isEmpty ? "" : " at \(p)"
}

private func describe(_ error: DecodingError) -> String {
    func path(_ context: DecodingError.Context) -> String { describe(context.codingPath) }
    switch error {
    case .keyNotFound(let key, let context): return "missing \"\(key.stringValue)\"\(path(context))"
    case .typeMismatch(_, let context): return "wrong type\(path(context)): \(context.debugDescription)"
    case .valueNotFound(_, let context): return "missing value\(path(context))"
    case .dataCorrupted(let context): return "\(context.debugDescription)\(path(context))"
    @unknown default: return "\(error)"
    }
}

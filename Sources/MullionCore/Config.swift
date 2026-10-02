import Foundation

public struct Grid: Decodable, Equatable {
    public var columns: Int
    public var rows: Int

    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
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

    /// Decodes and validates a config file. Errors name the offending shortcut so they are easy to fix.
    public static func parse(_ data: Data) throws -> Config {
        let raw: RawConfig
        do {
            raw = try JSONDecoder().decode(RawConfig.self, from: data)
        } catch let error as DecodingError {
            throw ConfigError.invalidJSON(describe(error))
        }

        let grid = raw.grid ?? Grid(columns: 6, rows: 6)
        guard grid.columns > 0, grid.rows > 0 else {
            throw ConfigError.invalid("grid columns and rows must be at least 1")
        }
        let gap = raw.gap ?? 0
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

        return Config(grid: grid, gap: gap, cycleScreens: raw.cycleScreens ?? true, shortcuts: shortcuts)
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
}

private struct RawShortcut: Decodable {
    var keys: String
    var cells: Cells
}

private func describe(_ error: DecodingError) -> String {
    func path(_ context: DecodingError.Context) -> String {
        let p = context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
        return p.isEmpty ? "" : " at \(p)"
    }
    switch error {
    case .keyNotFound(let key, let context): return "missing \"\(key.stringValue)\"\(path(context))"
    case .typeMismatch(_, let context): return "wrong type\(path(context)): \(context.debugDescription)"
    case .valueNotFound(_, let context): return "missing value\(path(context))"
    case .dataCorrupted(let context): return "\(context.debugDescription)\(path(context))"
    @unknown default: return "\(error)"
    }
}

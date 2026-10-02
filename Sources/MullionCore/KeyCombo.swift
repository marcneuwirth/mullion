import Foundation

/// A parsed shortcut like "ctrl+cmd+left", expressed as the raw values Carbon's RegisterEventHotKey expects.
public struct KeyCombo: Hashable {
    /// macOS virtual key code (kVK_*).
    public var keyCode: UInt32
    /// Carbon modifier mask (cmdKey | controlKey | ...).
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public init(parsing text: String) throws {
        let parts = text.lowercased().split(separator: "+", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let keyName = parts.last, !keyName.isEmpty else {
            throw KeyComboError("expected something like \"ctrl+cmd+left\"")
        }

        var modifiers: UInt32 = 0
        for name in parts.dropLast() {
            guard let flag = Modifier.byName[name] else {
                throw KeyComboError("unknown modifier \"\(name)\" (use ctrl, cmd, alt, shift)")
            }
            guard modifiers & flag == 0 else { throw KeyComboError("modifier \"\(name)\" is repeated") }
            modifiers |= flag
        }
        guard modifiers != 0 else {
            throw KeyComboError("needs at least one modifier, or it would swallow the key everywhere")
        }
        guard let keyCode = KeyCode.byName[keyName] else {
            throw KeyComboError("unknown key \"\(keyName)\"")
        }
        self.init(keyCode: keyCode, modifiers: modifiers)
    }
}

public struct KeyComboError: Error, Equatable {
    public let message: String
    init(_ message: String) { self.message = message }
}

/// Carbon modifier masks, from Carbon/HIToolbox/Events.h.
public enum Modifier {
    public static let cmd: UInt32 = 0x0100
    public static let shift: UInt32 = 0x0200
    public static let option: UInt32 = 0x0800
    public static let control: UInt32 = 0x1000

    static let byName: [String: UInt32] = [
        "cmd": cmd, "command": cmd, "⌘": cmd,
        "shift": shift, "⇧": shift,
        "alt": option, "opt": option, "option": option, "⌥": option,
        "ctrl": control, "control": control, "⌃": control,
    ]
}

/// Virtual key codes, from Carbon/HIToolbox/Events.h (ANSI layout positions).
public enum KeyCode {
    static let byName: [String: UInt32] = {
        var map: [String: UInt32] = [
            "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05, "z": 0x06, "x": 0x07,
            "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10,
            "t": 0x11, "o": 0x1F, "u": 0x20, "i": 0x22, "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28,
            "n": 0x2D, "m": 0x2E,
            "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "9": 0x19, "7": 0x1A,
            "8": 0x1C, "0": 0x1D,
            "=": 0x18, "equal": 0x18, "-": 0x1B, "minus": 0x1B, "]": 0x1E, "rightbracket": 0x1E,
            "[": 0x21, "leftbracket": 0x21, "'": 0x27, "quote": 0x27, ";": 0x29, "semicolon": 0x29,
            "\\": 0x2A, "backslash": 0x2A, ",": 0x2B, "comma": 0x2B, "/": 0x2C, "slash": 0x2C,
            ".": 0x2F, "period": 0x2F, "`": 0x32, "grave": 0x32,
            "return": 0x24, "enter": 0x24, "tab": 0x30, "space": 0x31, "delete": 0x33,
            "backspace": 0x33, "escape": 0x35, "esc": 0x35, "forwarddelete": 0x75,
            "home": 0x73, "end": 0x77, "pageup": 0x74, "pagedown": 0x79,
            "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,
        ]
        let functionKeys: [UInt32] = [
            0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D, 0x67, 0x6F, 0x69, 0x6B, 0x71,
        ]
        for (i, code) in functionKeys.enumerated() { map["f\(i + 1)"] = code }
        return map
    }()
}

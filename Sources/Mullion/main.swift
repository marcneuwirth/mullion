#if os(macOS)
import AppKit
import MullionCore

/// Fixed rather than read from $XDG_CONFIG_HOME: the LaunchAgent that runs Mullion never sees the shell's
/// environment, so `--check` in a terminal would validate a different file than the app loads.
func defaultConfigURL() -> URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/mullion/config.json")
}

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first ?? "" {
case "--check":
    // `Mullion --check [path]` validates a config without touching any hotkeys.
    let url = arguments.dropFirst().first.map { URL(fileURLWithPath: $0) } ?? defaultConfigURL()
    do {
        let config = try Config.parse(try Data(contentsOf: url))
        print("\(url.path): OK, \(config.shortcuts.count) shortcuts on a \(config.grid.columns)x\(config.grid.rows) grid")
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("\(url.path): \(error)\n".utf8))
        exit(1)
    }
case "--help", "-h":
    print("""
    usage: Mullion [--check [path]]

    Runs in the background and moves the focused window when a configured shortcut is pressed.
    Config: \(defaultConfigURL().path) (reloaded automatically when it changes)
    """)
    exit(0)
case "":
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let mullion = Mullion(configURL: defaultConfigURL())
        mullion.start()
        app.run()
    }
case let other:
    FileHandle.standardError.write(Data("unknown argument \(other); try --help\n".utf8))
    exit(2)
}
#else
print("Mullion only runs on macOS.")
#endif

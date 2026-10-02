#if os(macOS)
import AppKit
import MullionCore

/// Fixed rather than read from $XDG_CONFIG_HOME: an app opened from Finder or Login Items never sees the
/// shell's environment, so `--check` in a terminal would validate a different file than the app loads.
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
case "--unregister":
    // Used by `make uninstall` to take Mullion out of Login Items before the app is deleted.
    do {
        try LoginItem.unregister()
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("could not remove from Login Items: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
case "--help", "-h":
    print("""
    usage: Mullion [--check [path] | --unregister]

    Runs in the background and moves the focused window when a configured shortcut is pressed.
    Opening the app again while it runs opens the config file.
    Config: \(defaultConfigURL().path) (reloaded automatically when it changes)
    Log:    \(Log.url.path)
    """)
    exit(0)
case "":
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate(mullion: Mullion(configURL: defaultConfigURL()))
        app.delegate = delegate
        app.run()
    }
case let other:
    FileHandle.standardError.write(Data("unknown argument \(other); try --help\n".utf8))
    exit(2)
}
#else
print("Mullion only runs on macOS.")
#endif

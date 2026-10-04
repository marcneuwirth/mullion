#if os(macOS)
import AppKit
import MullionCore

/// Fixed rather than read from $XDG_CONFIG_HOME: an app opened from Finder or Login Items never sees the
/// shell's environment, so `--check` in a terminal would validate a different file than the app loads.
func defaultConfigURL() -> URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/mullion/config.json")
}

let bundleID = "com.marcneuwirth.mullion"

/// The app this executable is in. Bundle.main doesn't follow symlinks, so run through Homebrew's `mullion`
/// link it would miss the app.
let appBundle: Bundle? = {
    if Bundle.main.bundleIdentifier == bundleID { return Bundle.main }
    guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else { return nil }
    let app = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return Bundle(url: app).flatMap { $0.bundleIdentifier == bundleID ? $0 : nil }
}()

/// The config's summary on success, or why it can't be used.
func checkConfig(at url: URL) -> Result<String, CheckError> {
    guard let data = try? Data(contentsOf: url) else {
        let missing = !FileManager.default.fileExists(atPath: url.path)
        return .failure(CheckError(missing ? "missing (Mullion writes a default when it starts)" : "cannot be read"))
    }
    do {
        let config = try Config.parse(data)
        return .success("OK, \(config.shortcuts.count) shortcuts on a \(config.grid.columns)x\(config.grid.rows) grid")
    } catch {
        return .failure(CheckError("\(error)"))
    }
}

struct CheckError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

/// Other running copies of Mullion; excludes this process, which is the command-line one.
func runningInstances() -> [NSRunningApplication] {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        .filter { $0.processIdentifier != getpid() }
}

/// Prints whether Mullion is running, the config check and the last lines of the log. True if all is well.
func printStatus() -> Bool {
    let version = appBundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "(unbundled build)"
    print("Mullion \(version)")

    let pids = runningInstances().map { String($0.processIdentifier) }
    if pids.isEmpty {
        print("running: no; start it with `mullion --restart` or by opening Mullion.app")
    } else {
        print("running: yes (pid \(pids.joined(separator: ", ")))")
    }

    let config = checkConfig(at: defaultConfigURL())
    switch config {
    case .success(let summary): print("config:  \(defaultConfigURL().path): \(summary)")
    case .failure(let error): print("config:  \(defaultConfigURL().path): \(error.message)")
    }

    print("log:     \(Log.url.path)")
    if let log = try? String(contentsOf: Log.url, encoding: .utf8) {
        for line in log.split(separator: "\n").suffix(10) { print("  \(line)") }
    }
    if case .success = config { return !pids.isEmpty }
    return false
}

/// Quits any running Mullion, waits for it to exit, and opens the app again.
func restart() -> Never {
    for app in runningInstances() {
        let pid = app.processIdentifier
        app.terminate()
        let deadline = Date().addingTimeInterval(5)
        while kill(pid, 0) == 0 && Date() < deadline { usleep(100_000) }
        if kill(pid, 0) == 0 { app.forceTerminate() }
    }
    // Reopen this copy, so a build in another folder doesn't start instead; unbundled, let Launch Services pick.
    let open = Process()
    open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    open.arguments = appBundle.map { [$0.bundlePath] } ?? ["-b", bundleID]
    do {
        try open.run()
        open.waitUntilExit()
    } catch {
        FileHandle.standardError.write(Data("could not open Mullion: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
    if open.terminationStatus != 0 { exit(1) }
    print("Mullion restarted; log: \(Log.url.path)")
    exit(0)
}

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first ?? "" {
case "--check":
    // `Mullion --check [path]` validates a config without touching any hotkeys.
    let url = arguments.dropFirst().first.map { URL(fileURLWithPath: $0) } ?? defaultConfigURL()
    switch checkConfig(at: url) {
    case .success(let summary):
        print("\(url.path): \(summary)")
        exit(0)
    case .failure(let error):
        FileHandle.standardError.write(Data("\(url.path): \(error.message)\n".utf8))
        exit(1)
    }
case "--status":
    exit(printStatus() ? 0 : 1)
case "--restart":
    restart()
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
    usage: Mullion [--status | --restart | --check [path] | --unregister]

    Runs in the background and moves the focused window when a configured shortcut is pressed.
    Opening the app again while it runs opens the config file.

      --status    Show whether Mullion is running, check the config, and print the end of the log
      --restart   Quit Mullion if it is running and start it again
      --check     Validate a config file (the default one if no path is given) and exit
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

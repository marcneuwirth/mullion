#if os(macOS)
import AppKit
import MullionCore

/// Ties it together: loads the config, registers its shortcuts and places the focused window on each press.
@MainActor
final class Mullion {
    let configURL: URL
    private let hotKeys = HotKeys()
    private var config: Config?
    private var lastContents: Data?
    private var reportedUnreadable = false
    private var lastPlacement: (window: AXUIElement, placement: Placement)?
    private var reloadTimer: Timer?

    init(configURL: URL) {
        self.configURL = configURL
    }

    func start() {
        if !Windows.isTrusted(prompt: true) {
            Log.info("needs Accessibility permission: System Settings > Privacy & Security > Accessibility")
        }
        writeDefaultConfigIfMissing()
        reloadIfChanged()
        // Polling a tiny file once a second is cheap and, unlike file-system events, survives editors
        // that save by replacing the file.
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadIfChanged() }
        }
    }

    // MARK: Config

    private func writeDefaultConfigIfMissing() {
        guard !FileManager.default.fileExists(atPath: configURL.path) else { return }
        do {
            try FileManager.default.createDirectory(
                at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(Config.defaultJSON.utf8).write(to: configURL)
            Log.info("wrote default config to \(configURL.path)")
        } catch {
            Log.error("could not write default config to \(configURL.path): \(error.localizedDescription)")
        }
    }

    private func reloadIfChanged() {
        guard let data = try? Data(contentsOf: configURL) else {
            if !reportedUnreadable {
                Log.error("cannot read \(configURL.path); keeping current shortcuts")
                reportedUnreadable = true
            }
            return
        }
        reportedUnreadable = false
        guard data != lastContents else { return }
        lastContents = data

        do {
            apply(try Config.parse(data))
        } catch {
            Log.error("\(error); keeping \(config == nil ? "no shortcuts" : "the previous config")")
            NSSound.beep()
        }
    }

    private func apply(_ newConfig: Config) {
        hotKeys.unregisterAll()
        lastPlacement = nil
        config = newConfig
        var registered = 0
        for (index, shortcut) in newConfig.shortcuts.enumerated() {
            let ok = hotKeys.register(shortcut.combo) { [weak self] in self?.place(index) }
            if ok {
                registered += 1
            } else {
                Log.error("\"\(shortcut.keys)\" is already taken by another app (is Divvy still running?)")
            }
        }
        Log.info("loaded \(registered) of \(newConfig.shortcuts.count) shortcuts from \(configURL.path)")
    }

    // MARK: Placing windows

    private func place(_ index: Int) {
        guard let config, config.shortcuts.indices.contains(index) else { return }
        guard Windows.isTrusted(prompt: false) else {
            Log.error("no Accessibility permission yet")
            _ = Windows.isTrusted(prompt: true)
            NSSound.beep()
            return
        }
        guard let window = Windows.focusedWindow(), let current = Windows.frame(of: window) else {
            NSSound.beep()
            return
        }
        let screens = Layout.cycleOrder(Screens.visibleFrames())
        guard !screens.isEmpty else { return }

        let cells = config.shortcuts[index].cells
        var screen = Layout.screenIndex(for: current, in: screens)
        var target = Layout.frame(for: cells, grid: config.grid, in: screens[screen], gap: config.gap)

        if config.cycleScreens, screens.count > 1 {
            let last = lastPlacement.flatMap { CFEqual($0.window, window) ? $0.placement : nil }
            if Layout.isRepeat(current: current, target: target, last: last, shortcutIndex: index) {
                screen = (screen + 1) % screens.count
                target = Layout.frame(for: cells, grid: config.grid, in: screens[screen], gap: config.gap)
            }
        }

        Windows.setFrame(target, of: window)
        let actual = Windows.frame(of: window) ?? target
        lastPlacement = (window, Placement(shortcutIndex: index, frame: actual))
    }
}

enum Log {
    static func info(_ message: String) { write(message) }
    static func error(_ message: String) { write("error: \(message)") }

    private static func write(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        FileHandle.standardError.write(Data("\(stamp) mullion: \(message)\n".utf8))
    }
}
#endif

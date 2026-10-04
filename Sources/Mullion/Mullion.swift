#if os(macOS)
import AppKit
import MullionCore

/// Starts Mullion once AppKit is up. Opening the app again while it runs opens the config file, since
/// there is no other UI to show.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let mullion: Mullion

    init(mullion: Mullion) {
        self.mullion = mullion
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LoginItem.registerOnFirstLaunch()
        mullion.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        mullion.openConfig()
        return false
    }
}

/// Ties it together: registers the config's shortcuts and places the focused window on each press.
@MainActor
final class Mullion {
    private let configFile: ConfigFile
    private let hotKeys = HotKeys()
    private var config: Config?
    private var lastPlacement: (window: AXUIElement, placement: Placement)?

    init(configURL: URL) {
        configFile = ConfigFile(url: configURL)
    }

    func start() {
        if !Windows.isTrusted(prompt: true) {
            Log.info("needs Accessibility permission: System Settings > Privacy & Security > Accessibility")
        }
        configFile.watch { [weak self] in self?.apply($0) }
    }

    func openConfig() {
        configFile.open()
    }

    private func apply(_ newConfig: Config) {
        hotKeys.unregisterAll()
        lastPlacement = nil
        config = newConfig
        var registered = 0
        for shortcut in newConfig.shortcuts {
            let ok = hotKeys.register(shortcut.combo) { [weak self] in self?.place(shortcut) }
            if ok {
                registered += 1
            } else {
                Log.error("\"\(shortcut.keys)\" is already taken by another app (is Divvy still running?)")
            }
        }
        Log.info("loaded \(registered) of \(newConfig.shortcuts.count) shortcuts from \(configFile.url.path)")
    }

    private func place(_ shortcut: Shortcut) {
        guard let config else { return }
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
        let last = lastPlacement.flatMap { CFEqual($0.window, window) ? $0.placement : nil }
        guard let target = config.target(for: shortcut, window: current, screens: Screens.visibleFrames(), last: last)
        else { return }

        Windows.setFrame(target, of: window)
        let actual = Windows.frame(of: window) ?? target
        lastPlacement = (window, Placement(shortcut: shortcut, frame: actual))
    }
}
#endif

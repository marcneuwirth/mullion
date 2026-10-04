#if os(macOS)
import AppKit
import MullionCore

/// The config file on disk. Writes the default if there is none and reloads it whenever it changes; if the
/// file can't be read or has an error, Mullion beeps, logs it, and keeps the config it already has.
@MainActor
final class ConfigFile {
    let url: URL
    private var onLoad: ((Config) -> Void)?
    private var hasLoaded = false
    private var lastContents: Data?
    private var reportedUnreadable = false
    private var reloadTimer: Timer?

    init(url: URL) {
        self.url = url
    }

    /// Loads the config now and again each time it changes, passing every valid version to `onLoad`.
    func watch(onLoad: @escaping (Config) -> Void) {
        self.onLoad = onLoad
        writeDefaultIfMissing()
        reloadIfChanged()
        // Polling a tiny file once a second is cheap and, unlike file-system events, survives editors
        // that save by replacing the file.
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadIfChanged() }
        }
    }

    func open() {
        writeDefaultIfMissing()
        // .json often has no default app, or one that won't edit it; fall back to TextEdit.
        if !NSWorkspace.shared.open(url) {
            let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
            NSWorkspace.shared.open([url], withApplicationAt: textEdit, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func writeDefaultIfMissing() {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(Config.defaultJSON.utf8).write(to: url)
            Log.info("wrote default config to \(url.path)")
        } catch {
            Log.error("could not write default config to \(url.path): \(error.localizedDescription)")
        }
    }

    private func reloadIfChanged() {
        guard let data = try? Data(contentsOf: url) else {
            if !reportedUnreadable {
                Log.error("cannot read \(url.path); keeping \(kept)")
                NSSound.beep()
                reportedUnreadable = true
            }
            return
        }
        reportedUnreadable = false
        guard data != lastContents else { return }
        lastContents = data

        do {
            let config = try Config.parse(data)
            hasLoaded = true
            onLoad?(config)
        } catch {
            Log.error("\(error); keeping \(kept)")
            NSSound.beep()
        }
    }

    private var kept: String { hasLoaded ? "the previous config" : "no shortcuts" }
}
#endif

#if os(macOS)
import Foundation
import ServiceManagement

/// Starts Mullion at login through System Settings > General > Login Items.
enum LoginItem {
    private static let registeredKey = "registeredLoginItem"

    /// Registers once, on the first launch, so turning it off in System Settings sticks.
    static func registerOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: registeredKey) else { return }
        // A bare `swift run` binary has no bundle to register, and an app opened straight from Downloads
        // runs from a randomized read-only copy that will be gone at the next login.
        guard Bundle.main.bundleIdentifier != nil else { return }
        guard !Bundle.main.bundlePath.contains("/AppTranslocation/") else {
            Log.error("move Mullion.app to /Applications and open it again to start it at login")
            return
        }
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: registeredKey)
            Log.info("added to Login Items")
        } catch {
            Log.error("could not add to Login Items: \(error.localizedDescription)")
        }
    }

    static func unregister() throws {
        UserDefaults.standard.removeObject(forKey: registeredKey)
        try SMAppService.mainApp.unregister()
    }
}
#endif

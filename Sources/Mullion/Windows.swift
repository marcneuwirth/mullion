#if os(macOS)
import AppKit
import ApplicationServices
import MullionCore

/// Reads and moves the focused window through the Accessibility API.
@MainActor
enum Windows {
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    static func focusedWindow() -> AXUIElement? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    static func frame(of window: AXUIElement) -> Frame? {
        var position = CGPoint.zero
        var size = CGSize.zero
        guard copy(kAXPositionAttribute, of: window, type: .cgPoint, into: &position),
              copy(kAXSizeAttribute, of: window, type: .cgSize, into: &size)
        else { return nil }
        return Frame(x: position.x, y: position.y, w: size.width, h: size.height)
    }

    static func setFrame(_ frame: Frame, of window: AXUIElement) {
        withoutEnhancedUI(for: window) {
            let position = CGPoint(x: frame.x, y: frame.y)
            let size = CGSize(width: frame.w, height: frame.h)
            // Size, then position, then size again: the first resize can be clamped by the old screen's
            // bounds and some apps only accept a size once they have moved.
            set(kAXSizeAttribute, of: window, type: .cgSize, value: size)
            set(kAXPositionAttribute, of: window, type: .cgPoint, value: position)
            set(kAXSizeAttribute, of: window, type: .cgSize, value: size)
        }
    }

    /// Chromium and Electron apps turn on AXEnhancedUserInterface for VoiceOver, which makes them animate
    /// every frame change slowly and sometimes ignore it. Switch it off for the move and restore it after.
    private static func withoutEnhancedUI(for window: AXUIElement, _ body: () -> Void) {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else { return body() }
        let app = AXUIElementCreateApplication(pid)
        let attribute = "AXEnhancedUserInterface" as CFString
        var value: CFTypeRef?
        let enabled = AXUIElementCopyAttributeValue(app, attribute, &value) == .success
            && (value as? Bool) == true
        if enabled { AXUIElementSetAttributeValue(app, attribute, false as CFTypeRef) }
        body()
        if enabled { AXUIElementSetAttributeValue(app, attribute, true as CFTypeRef) }
    }

    private static func copy<T>(_ attribute: String, of element: AXUIElement, type: AXValueType, into result: inout T) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID()
        else { return false }
        return withUnsafeMutablePointer(to: &result) { AXValueGetValue(value as! AXValue, type, $0) }
    }

    private static func set<T>(_ attribute: String, of element: AXUIElement, type: AXValueType, value: T) {
        guard let axValue = withUnsafePointer(to: value, { AXValueCreate(type, $0) }) else { return }
        AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
    }
}
#endif

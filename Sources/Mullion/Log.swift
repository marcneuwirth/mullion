#if os(macOS)
import Foundation

/// Appends to ~/Library/Logs/Mullion.log (readable in Console.app), and echoes to the terminal when there is one.
enum Log {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Mullion.log")

    static func info(_ message: String) { write(message) }
    static func error(_ message: String) { write("error: \(message)") }

    private static let file: FileHandle? = {
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fm.fileExists(atPath: url.path) { fm.createFile(atPath: url.path, contents: nil) }
        let handle = try? FileHandle(forWritingTo: url)
        _ = try? handle?.seekToEnd()
        return handle
    }()

    private static func write(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = Data("\(stamp) mullion: \(message)\n".utf8)
        file?.write(line)
        if isatty(STDERR_FILENO) != 0 { FileHandle.standardError.write(line) }
    }
}
#endif

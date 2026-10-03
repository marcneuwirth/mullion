#if os(macOS)
import Foundation

enum Log {
    static func info(_ message: String) { write(message) }
    static func error(_ message: String) { write("error: \(message)") }

    private static func write(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        FileHandle.standardError.write(Data("\(stamp) mullion: \(message)\n".utf8))
    }
}
#endif

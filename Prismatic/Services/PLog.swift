import Foundation

/// Thin wrapper over the C logger so Swift and the native loader share one on-device log file.
enum PLog {
    static func log(_ s: String) { PrismaticLogString(s) }
    static var path: String { PrismaticLogPath() }
    static func read() -> String { (try? String(contentsOfFile: path, encoding: .utf8)) ?? "(no log yet)" }
    static func clear() { try? FileManager.default.removeItem(atPath: path) }
}

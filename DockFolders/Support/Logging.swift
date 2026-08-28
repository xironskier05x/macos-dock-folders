import Foundation

public enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

public struct Logger {
    public static func log(_ message: String, level: LogLevel = .info, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        let dateStr = ISO8601DateFormatter().string(from: Date())
        print("[\(dateStr)] [\(level.rawValue)] [\(filename):\(line)] \(message)")
    }
}

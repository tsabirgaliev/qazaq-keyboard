import Foundation
import os

/// Long-press table generated from OVERLAY by tools/build_variants.py: {"н": ["ң"], "у": ["ұ", "ү"], ...}.
enum Variants {
    static let table: [String: [String]] = {
        guard let url = Bundle.main.url(forResource: "variants", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: [String]].self, from: data)
        else {
            Log.error("variants.json missing or unreadable; long-press disabled")
            return [:]
        }
        return table
    }()
}

/// Logging. Key events are only described when debugging is switched on, because they are what the user types:
///   defaults write dev.tair.inputmethod.Qazaq debug -bool true   (then also mirrored to /tmp/qazaq.log)
enum Log {
    private static let logger = Logger(subsystem: "dev.tair.inputmethod.Qazaq", category: "hold")
    static var debugEnabled: Bool { UserDefaults.standard.bool(forKey: "debug") }

    static func error(_ s: String) { logger.error("\(s, privacy: .public)") }

    static func debug(_ s: @autoclosure () -> String) {
        guard debugEnabled else { return }
        let msg = s()
        logger.debug("\(msg, privacy: .public)")
        let line = "\(Date()) \(msg)\n"
        let url = URL(fileURLWithPath: "/tmp/qazaq.log")
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close()
        } else {
            try? line.write(to: url, atomically: false, encoding: .utf8)
        }
    }
}

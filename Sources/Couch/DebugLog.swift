// DebugLog.swift — append-only file logger for pipeline diagnosis.
// Writes ~/Library/Logs/Couch.log (truncated at each launch).
// Local tool: always on. Tail it while testing:
//   tail -f ~/Library/Logs/Couch.log

import Foundation

enum DebugLog {
    static let url: URL = {
        let dir = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("Couch.log")
    }()

    static func reset() {
        try? Data().write(to: url)
    }

    static func log(_ message: String) {
        let line = "\(Date()) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: data)
            return
        }
        if let fh = try? FileHandle(forWritingTo: url) {
            fh.seekToEndOfFile()
            fh.write(data)
            try? fh.close()
        }
    }
}
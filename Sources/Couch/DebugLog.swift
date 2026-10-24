// DebugLog.swift — append-only file logger for pipeline diagnosis.
// Writes ~/Library/Logs/Couch.log (truncated at each launch, capped at 1 MB).
// Local tool: always on. Tail it while testing:
//   tail -f ~/Library/Logs/Couch.log

import Foundation

enum DebugLog {
    private static let maxBytes: UInt64 = 1_000_000

    static let url: URL = {
        let dir = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("Couch.log")
    }()

    private static let queue = DispatchQueue(label: "couch.debuglog")
    private static var handle: FileHandle?

    private static func open() -> FileHandle? {
        if handle == nil {
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            handle = try? FileHandle(forWritingTo: url)
        }
        return handle
    }

    static func reset() {
        queue.sync {
            try? handle?.close()
            handle = nil
            try? Data().write(to: url)
        }
    }

    static func log(_ message: String) {
        let line = "\(Date()) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        queue.sync {
            guard let fh = open() else { return }
            let end = (try? fh.seekToEnd()) ?? 0
            if end > maxBytes {
                try? fh.truncate(atOffset: 0)
            }
            try? fh.write(contentsOf: data)
        }
    }
}

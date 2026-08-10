import Foundation
import SwiftUI

/// Lightweight on-device diagnostic logger. Records a breadcrumb trail of
/// the user's navigation / key actions to a plain-text file in the app's
/// Documents/Logs directory, which is exposed in the Files app (via
/// UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace) so users can
/// grab it and attach it to a GitHub issue.
///
/// Privacy:
/// - Disabled-able from Settings (diagnostic_logging_enabled).
/// - Only call sites we control feed it, and every line passes through a
///   redactor that masks anything that looks like an email, a cookie /
///   token (long hex/base64 runs), or an Authorization/Cookie header
///   value, so secrets and PII don't leak into the file.
/// - Everything stays on the device; it's never uploaded automatically.
/// - Auto-pruned: the current file is size-capped and rolls once; old
///   roll files beyond a small count, and any file older than the
///   retention window, are deleted.
enum AppLogger {
    static let enabledKey = "diagnostic_logging_enabled"

    private static let maxFileBytes = 512 * 1024            // 512 KB per file
    private static let maxRollCount = 2                     // keep .log + .1.log
    private static let retention: TimeInterval = 7 * 24 * 3600 // 7 days

    private static let queue = DispatchQueue(label: "com.han1meviewer.applogger")
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static var isEnabled: Bool {
        // Default ON so a log already exists when the user hits a bug.
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Records one breadcrumb. No-op when logging is disabled.
    static func log(_ message: String) {
        guard isEnabled else { return }
        let line = "[\(isoFormatter.string(from: Date()))] \(redact(message))\n"
        queue.async {
            appendAndRotate(line)
            pruneOldFiles()
        }
    }

    /// Directory shown in Files → On My iPhone/iPad → Han1meViewer → Logs.
    static func logsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Clears every diagnostic log file.
    static func clear() {
        queue.async {
            let dir = logsDirectory()
            let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for url in urls { try? FileManager.default.removeItem(at: url) }
        }
    }

    /// Approximate total size of the logs on disk (for the settings row).
    static func totalSizeBytes() -> Int {
        let dir = logsDirectory()
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return urls.reduce(0) { sum, url in
            sum + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    // MARK: - Internals

    private static var currentFileURL: URL {
        logsDirectory().appendingPathComponent("app.log")
    }

    private static func rolledFileURL(_ index: Int) -> URL {
        logsDirectory().appendingPathComponent("app.\(index).log")
    }

    private static func appendAndRotate(_ line: String) {
        let url = currentFileURL
        let fm = FileManager.default

        // Rotate if the current file would exceed the cap.
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maxFileBytes {
            // Shift app.(n-1).log -> app.n.log, then app.log -> app.1.log
            for i in stride(from: maxRollCount - 1, through: 1, by: -1) {
                let from = rolledFileURL(i)
                let to = rolledFileURL(i + 1)
                if fm.fileExists(atPath: from.path) {
                    try? fm.removeItem(at: to)
                    try? fm.moveItem(at: from, to: to)
                }
            }
            try? fm.removeItem(at: rolledFileURL(1))
            try? fm.moveItem(at: url, to: rolledFileURL(1))
        }

        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func pruneOldFiles() {
        let dir = logsDirectory()
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        let cutoff = Date().addingTimeInterval(-retention)
        for url in urls {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if modified < cutoff {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Redaction

    private static let emailRegex = try? NSRegularExpression(
        pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
    )
    /// Long hex / base64-ish runs (cookies, CSRF tokens, session ids).
    private static let tokenRegex = try? NSRegularExpression(
        pattern: #"[A-Za-z0-9+/=_-]{24,}"#
    )
    /// Cookie / token query params or header-ish key=value pairs.
    private static let kvSecretRegex = try? NSRegularExpression(
        pattern: #"(?i)(cookie|token|session|csrf|authorization|password|_token|xsrf)([=:]\s*)\S+"#
    )

    private static func redact(_ input: String) -> String {
        var s = input
        let full = { (str: String) in NSRange(str.startIndex..<str.endIndex, in: str) }
        if let r = kvSecretRegex {
            s = r.stringByReplacingMatches(in: s, range: full(s), withTemplate: "$1$2***")
        }
        if let r = emailRegex {
            s = r.stringByReplacingMatches(in: s, range: full(s), withTemplate: "***@***")
        }
        if let r = tokenRegex {
            s = r.stringByReplacingMatches(in: s, range: full(s), withTemplate: "***")
        }
        return s
    }
}

extension View {
    /// Logs a screen-appearance breadcrumb when this view appears. Use a
    /// short, non-sensitive label (screen name + maybe a video code).
    func logScreen(_ name: String) -> some View {
        onAppear { AppLogger.log("screen: \(name)") }
    }
}

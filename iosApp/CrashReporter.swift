import Foundation

enum CrashReporter {
    private static let maxReportCount = 5

    static func install() {
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.record(exception: exception)
        }
    }

    static func latestReportSummary() -> String? {
        guard let reportURL = reportURLs().first,
              let contents = try? String(contentsOf: reportURL, encoding: .utf8) else {
            return nil
        }
        return contents
            .split(separator: "\n")
            .prefix(3)
            .joined(separator: "\n")
    }

    static func clearReports() {
        reportURLs().forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func record(exception: NSException) {
        record(
            title: "exception: \(exception.name.rawValue)",
            detail: "reason: \(exception.reason ?? "unknown")",
            callStack: exception.callStackSymbols.joined(separator: "\n")
        )
    }

    private static func record(title: String, detail: String, callStack: String) {
        do {
            let directoryURL = try reportDirectoryURL()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let reportURL = directoryURL.appendingPathComponent(reportFileName())
            let report = """
            time: \(ISO8601DateFormatter().string(from: Date()))
            \(title)
            \(detail)
            callStack:
            \(callStack)
            """
            try report.write(to: reportURL, atomically: true, encoding: .utf8)
            pruneReports(in: directoryURL)
        } catch {
            return
        }
    }

    private static func reportURLs() -> [URL] {
        guard let directoryURL = try? reportDirectoryURL(),
              let urls = try? FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }
        return urls.sorted { lhs, rhs in
            modificationDate(lhs) > modificationDate(rhs)
        }
    }

    private static func pruneReports(in directoryURL: URL) {
        let staleReports = reportURLs().dropFirst(maxReportCount)
        staleReports.forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func reportDirectoryURL() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("CrashReports", isDirectory: true)
    }

    private static func reportFileName() -> String {
        let timestamp = ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        return "\(timestamp).log"
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}

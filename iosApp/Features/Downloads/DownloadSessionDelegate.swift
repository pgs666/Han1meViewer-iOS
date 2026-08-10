import Foundation

/// Runs on the URLSession delegate queue and forwards state mutations to the
/// main-actor-isolated download manager.
final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate {
    private weak var manager: DownloadManager?

    init(manager: DownloadManager) {
        self.manager = manager
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let key = downloadTask.taskDescription else { return }
        Task { @MainActor [weak manager] in
            manager?.handleProgress(
                key: key,
                totalBytesWritten: totalBytesWritten,
                totalBytesExpectedToWrite: totalBytesExpectedToWrite
            )
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let key = downloadTask.taskDescription else { return }
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let dest = DownloadManager.localFileURL(videoCode: parts[0], quality: parts[1])
        let fm = FileManager.default
        let parent = dest.deletingLastPathComponent()
        let srcExists = fm.fileExists(atPath: location.path)
        let parentExists = fm.fileExists(atPath: parent.path)
        let srcSize: Int64 = {
            guard let n = (try? fm.attributesOfItem(atPath: location.path))?[.size] as? NSNumber else { return -1 }
            return n.int64Value
        }()
        let didStart = location.startAccessingSecurityScopedResource()
        defer { if didStart { location.stopAccessingSecurityScopedResource() } }
        var removeErr = "ok"
        do { try fm.removeItem(at: dest) }
        catch let error as NSError {
            if !(error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError) {
                removeErr = "\(error.domain)#\(error.code) \(error.localizedDescription)"
            }
        }
        var copyErr = "ok"
        do { try fm.copyItem(at: location, to: dest) }
        catch let error as NSError {
            copyErr = "\(error.domain)#\(error.code) \(error.localizedDescription)"
        }
        let destExists = fm.fileExists(atPath: dest.path)
        let http = downloadTask.response as? HTTPURLResponse
        let status = http?.statusCode ?? -1
        let mime = http?.mimeType ?? "?"
        let size = (try? fm.attributesOfItem(atPath: dest.path))?[.size] as? NSNumber
        var magic = "?"
        if let file = try? FileHandle(forReadingFrom: dest) {
            let head = file.readData(ofLength: 16)
            try? file.close()
            let ascii = String(data: head, encoding: .ascii) ?? ""
            let hex = head.map { String(format: "%02x", $0) }.joined()
            magic = "ascii=\(ascii.prefix(16)) hex=\(hex)"
        }
        AppLogger.log(
            "download landed v=\(parts[0]) q=\(parts[1])"
            + " status=\(status) mime=\(mime)"
            + " src[exists=\(srcExists) bytes=\(srcSize) path=\(location.path)]"
            + " parent[exists=\(parentExists) path=\(parent.path)]"
            + " scoped=\(didStart) remove=[\(removeErr)] copy=[\(copyErr)]"
            + " dest[exists=\(destExists) bytes=\(size?.int64Value.description ?? "nil") magic=\(magic)]"
        )
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let key = task.taskDescription else { return }
        let httpStatus = (task.response as? HTTPURLResponse)?.statusCode
        let nsError = error as NSError?
        Task { @MainActor [weak manager] in
            manager?.handleCompletion(key: key, httpStatus: httpStatus, error: nsError)
        }
    }
}

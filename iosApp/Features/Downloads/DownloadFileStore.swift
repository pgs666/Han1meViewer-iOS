import Foundation

/// Owns every on-disk path and resume-data mutation used by downloads.
enum DownloadFileStore {
    static func downloadsRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func videoURL(videoCode: String, quality: String) -> URL {
        downloadsRoot().appendingPathComponent("\(videoCode)_\(quality).mp4")
    }

    static func resumeDataURL(videoCode: String, quality: String) -> URL {
        downloadsRoot().appendingPathComponent("\(videoCode)_\(quality).resume")
    }

    static func coverURL(videoCode: String, quality: String) -> URL {
        downloadsRoot().appendingPathComponent("\(videoCode)_\(quality).cover")
    }

    static func consumeResumeData(videoCode: String, quality: String) -> Data? {
        let url = resumeDataURL(videoCode: videoCode, quality: quality)
        guard let data = try? Data(contentsOf: url) else { return nil }
        try? FileManager.default.removeItem(at: url)
        return data
    }

    static func saveResumeData(_ data: Data, videoCode: String, quality: String) {
        try? data.write(to: resumeDataURL(videoCode: videoCode, quality: quality), options: .atomic)
    }

    static func removeFiles(videoCode: String, quality: String) {
        let urls = [
            videoURL(videoCode: videoCode, quality: quality),
            resumeDataURL(videoCode: videoCode, quality: quality),
            coverURL(videoCode: videoCode, quality: quality),
        ]
        urls.forEach { try? FileManager.default.removeItem(at: $0) }
    }
}

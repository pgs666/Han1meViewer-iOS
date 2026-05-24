import Foundation
import Nuke

enum CacheStorage {
    static func currentSize() -> Int64 {
        cacheDirectoryURLs.reduce(0) { total, url in
            total + directorySize(url)
        }
    }

    static func formattedSize() -> String {
        ByteCountFormatter.string(fromByteCount: currentSize(), countStyle: .file)
    }

    static func clear() {
        ImagePipeline.shared.cache.removeAll()
        URLCache.shared.removeAllCachedResponses()

        cacheDirectoryURLs.forEach { directoryURL in
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: []
            ) else {
                return
            }

            contents.forEach { itemURL in
                try? FileManager.default.removeItem(at: itemURL)
            }
        }
    }

    private static var cacheDirectoryURLs: [URL] {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
    }

    private static func directorySize(_ directoryURL: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [
                .isRegularFileKey,
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey,
            ]) else {
                continue
            }
            guard values.isRegularFile == true else {
                continue
            }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}

import Foundation
import Nuke

enum CacheStorage {
    private static let sizeCache = CacheSizeCache()

    static func currentSize() -> Int64 {
        if let cachedSize = sizeCache.currentValue(maxAge: 30) {
            return cachedSize
        }

        let size = cacheDirectoryURLs.reduce(0) { total, url in
            total + directorySize(url)
        }
        sizeCache.update(size)
        return size
    }

    static func formattedSize() -> String {
        ByteCountFormatter.string(fromByteCount: currentSize(), countStyle: .file)
    }

    static func formattedSizeAsync() async -> String {
        await Task.detached(priority: .utility) {
            formattedSize()
        }.value
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

        sizeCache.update(0)
    }

    static func clearAsync() async {
        await Task.detached(priority: .utility) {
            clear()
        }.value
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

private final class CacheSizeCache {
    private let lock = NSLock()
    private var value: Int64?
    private var updatedAt: Date?

    func currentValue(maxAge: TimeInterval) -> Int64? {
        lock.lock()
        defer { lock.unlock() }

        guard let value, let updatedAt else {
            return nil
        }
        guard Date().timeIntervalSince(updatedAt) <= maxAge else {
            return nil
        }
        return value
    }

    func update(_ value: Int64) {
        lock.lock()
        self.value = value
        self.updatedAt = Date()
        lock.unlock()
    }
}

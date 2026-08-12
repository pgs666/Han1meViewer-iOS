import Han1meShared

enum DownloadScheduler {
    static func nextQueuedItem(
        from items: [DownloadItem],
        excluding activeKeys: Set<String>
    ) -> DownloadItem? {
        items
            .filter {
                $0.state == Int32(DownloadState.queued.rawValue) &&
                    !activeKeys.contains("\($0.videoCode)|\($0.quality)")
            }
            .min { $0.addedAtEpochMillis < $1.addedAtEpochMillis }
    }
}

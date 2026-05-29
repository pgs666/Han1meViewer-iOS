package com.yenaly.han1meviewer.shared.download

import app.cash.sqldelight.coroutines.asFlow
import com.yenaly.han1meviewer.shared.db.Han1meDatabase
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * Download metadata persistence. The actual byte transfer happens on the
 * iOS side via a background URLSession; this store only mirrors the
 * task list / progress / state so the UI can render it and survive
 * restarts. Mirrors the WatchHistoryStore shape so the iOS bridge and
 * the jvmTest harness can use it the same way.
 *
 * State integer mapping (kept in sync with iOS DownloadState):
 *   0 queued, 1 downloading, 2 paused, 3 finished, 4 failed
 */
class DownloadStore(
    private val database: Han1meDatabase,
) {
    fun all(): List<DownloadItem> {
        return database.downloadQueries.selectAll(::map).executeAsList()
    }

    fun allFlow(): Flow<List<DownloadItem>> {
        return database.downloadQueries.selectAll(::map)
            .asFlow()
            .map { it.executeAsList() }
    }

    fun find(videoCode: String, quality: String): DownloadItem? {
        return database.downloadQueries.selectByKey(videoCode, quality, ::map).executeAsOneOrNull()
    }

    fun upsert(item: DownloadItem) {
        database.downloadQueries.upsert(
            video_code = item.videoCode,
            quality = item.quality,
            title = item.title,
            cover_url = item.coverUrl,
            remote_url = item.remoteUrl,
            local_path = item.localPath,
            total_bytes = item.totalBytes,
            downloaded_bytes = item.downloadedBytes,
            state = item.state.toLong(),
            added_at_epoch_millis = item.addedAtEpochMillis,
        )
    }

    fun updateProgress(videoCode: String, quality: String, downloadedBytes: Long, totalBytes: Long, state: Int) {
        database.downloadQueries.updateProgress(
            downloaded_bytes = downloadedBytes,
            total_bytes = totalBytes,
            state = state.toLong(),
            video_code = videoCode,
            quality = quality,
        )
    }

    fun updateState(videoCode: String, quality: String, state: Int) {
        database.downloadQueries.updateState(state.toLong(), videoCode, quality)
    }

    fun updateRemoteUrl(videoCode: String, quality: String, remoteUrl: String) {
        database.downloadQueries.updateRemoteUrl(remoteUrl, videoCode, quality)
    }

    fun delete(videoCode: String, quality: String) {
        database.downloadQueries.deleteByKey(videoCode, quality)
    }

    fun clear() {
        database.downloadQueries.deleteAll()
    }

    private fun map(
        videoCode: String,
        quality: String,
        title: String,
        coverUrl: String?,
        remoteUrl: String,
        localPath: String,
        totalBytes: Long,
        downloadedBytes: Long,
        state: Long,
        addedAtEpochMillis: Long,
    ): DownloadItem = DownloadItem(
        videoCode = videoCode,
        quality = quality,
        title = title,
        coverUrl = coverUrl,
        remoteUrl = remoteUrl,
        localPath = localPath,
        totalBytes = totalBytes,
        downloadedBytes = downloadedBytes,
        state = state.toInt(),
        addedAtEpochMillis = addedAtEpochMillis,
    )
}

data class DownloadItem(
    val videoCode: String,
    val quality: String,
    val title: String,
    val coverUrl: String?,
    val remoteUrl: String,
    val localPath: String,
    val totalBytes: Long,
    val downloadedBytes: Long,
    val state: Int,
    val addedAtEpochMillis: Long,
)

package com.yenaly.han1meviewer.shared.history

import com.yenaly.han1meviewer.shared.db.Han1meDatabase
import com.yenaly.han1meviewer.shared.model.WatchHistoryItem

class WatchHistoryStore(
    private val database: Han1meDatabase,
) {
    fun recent(): List<WatchHistoryItem> {
        return database.watchHistoryQueries.selectRecent(::mapHistoryItem).executeAsList()
    }

    fun record(
        videoCode: String,
        title: String,
        coverUrl: String?,
        watchedAtEpochMillis: Long,
        playbackPositionMillis: Long = 0,
    ) {
        database.watchHistoryQueries.upsert(
            video_code = videoCode,
            title = title,
            cover_url = coverUrl,
            watched_at_epoch_millis = watchedAtEpochMillis,
            playback_position_millis = playbackPositionMillis,
        )
    }

    fun delete(videoCode: String) {
        database.watchHistoryQueries.deleteByVideoCode(videoCode)
    }

    fun clear() {
        database.watchHistoryQueries.deleteAll()
    }

    private fun mapHistoryItem(
        videoCode: String,
        title: String,
        coverUrl: String?,
        watchedAtEpochMillis: Long,
        playbackPositionMillis: Long,
    ): WatchHistoryItem {
        return WatchHistoryItem(
            videoCode = videoCode,
            title = title,
            coverUrl = coverUrl,
            watchedAtEpochMillis = watchedAtEpochMillis,
            playbackPositionMillis = playbackPositionMillis,
        )
    }
}

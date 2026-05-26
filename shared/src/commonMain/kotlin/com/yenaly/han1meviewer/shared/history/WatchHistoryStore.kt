package com.yenaly.han1meviewer.shared.history

import app.cash.sqldelight.coroutines.asFlow
import com.yenaly.han1meviewer.shared.db.Han1meDatabase
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import com.yenaly.han1meviewer.shared.model.WatchHistoryItem

class WatchHistoryStore(
    private val database: Han1meDatabase,
) {
    fun recent(limit: Long = DEFAULT_RECENT_LIMIT): List<WatchHistoryItem> {
        return database.watchHistoryQueries.selectRecent(limit, ::mapHistoryItem).executeAsList()
    }

    fun recentFlow(limit: Long = DEFAULT_RECENT_LIMIT): Flow<List<WatchHistoryItem>> {
        return database.watchHistoryQueries.selectRecent(limit, ::mapHistoryItem)
            .asFlow()
            .map { query -> query.executeAsList() }
    }

    fun find(videoCode: String): WatchHistoryItem? {
        return database.watchHistoryQueries.selectByVideoCode(videoCode, ::mapHistoryItem).executeAsOneOrNull()
    }

    fun record(
        videoCode: String,
        title: String,
        coverUrl: String?,
        watchedAtEpochMillis: Long,
        playbackPositionMillis: Long = 0,
        releaseDateEpochMillis: Long = 0,
    ) {
        val existing = find(videoCode)
        if (existing != null) {
            // Already exists: update title/cover but preserve watched_at
            database.watchHistoryQueries.updateTitleAndCover(
                title = title,
                cover_url = coverUrl,
                video_code = videoCode,
            )
        } else {
            // New entry: insert with current timestamp
            database.watchHistoryQueries.insertIfNotExists(
                video_code = videoCode,
                title = title,
                cover_url = coverUrl,
                watched_at_epoch_millis = watchedAtEpochMillis,
                playback_position_millis = playbackPositionMillis.coerceAtLeast(0L),
                release_date_epoch_millis = releaseDateEpochMillis,
            )
            database.watchHistoryQueries.deleteOldestBeyondLimit(MAX_RETAINED_ITEMS)
        }
    }


    fun updateProgress(videoCode: String, playbackPositionMillis: Long) {
        database.watchHistoryQueries.updateProgress(
            playback_position_millis = playbackPositionMillis.coerceAtLeast(0L),
            video_code = videoCode,
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
        releaseDateEpochMillis: Long,
    ): WatchHistoryItem {
        return WatchHistoryItem(
            videoCode = videoCode,
            title = title,
            coverUrl = coverUrl,
            watchedAtEpochMillis = watchedAtEpochMillis,
            playbackPositionMillis = playbackPositionMillis,
            releaseDateEpochMillis = releaseDateEpochMillis,
        )
    }

    private companion object {
        const val DEFAULT_RECENT_LIMIT = 100L
        const val MAX_RETAINED_ITEMS = 1_000L
    }
}

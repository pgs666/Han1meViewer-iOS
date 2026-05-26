package com.yenaly.han1meviewer.shared.history

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.Serializable

class WatchHistoryFeature(
    private val store: WatchHistoryStore,
) {
    fun loadRecent(): WatchHistorySnapshot {
        return loadRecent(limit = DEFAULT_RECENT_LIMIT)
    }

    fun loadRecent(limit: Int): WatchHistorySnapshot {
        return WatchHistorySnapshot(
            items = store.recent(limit.toLong()).map { item ->
                WatchHistoryItemSnapshot(
                    videoCode = item.videoCode,
                    title = item.title,
                    coverUrl = item.coverUrl,
                    watchedAtEpochMillis = item.watchedAtEpochMillis,
                    playbackPositionMillis = item.playbackPositionMillis,
                )
            },
        )
    }

    fun recentFlow(limit: Int = DEFAULT_RECENT_LIMIT): Flow<WatchHistorySnapshot> {
        return store.recentFlow(limit.toLong()).map { items ->
            WatchHistorySnapshot(
                items = items.map { item ->
                    WatchHistoryItemSnapshot(
                        videoCode = item.videoCode,
                        title = item.title,
                        coverUrl = item.coverUrl,
                        watchedAtEpochMillis = item.watchedAtEpochMillis,
                        playbackPositionMillis = item.playbackPositionMillis,
                    )
                },
            )
        }
    }

    fun playbackPositionMillis(videoCode: String): Long {
        return store.find(videoCode)?.playbackPositionMillis ?: 0L
    }

    fun delete(videoCode: String): WatchHistorySnapshot {
        store.delete(videoCode)
        return loadRecent()
    }

    fun clear(): WatchHistorySnapshot {
        store.clear()
        return loadRecent()
    }

    private companion object {
        const val DEFAULT_RECENT_LIMIT = 100
    }
}

@Serializable
data class WatchHistorySnapshot(
    private val items: List<WatchHistoryItemSnapshot>,
) {
    fun itemCount(): Int = items.size

    fun itemAt(index: Int): WatchHistoryItemSnapshot? = items.getOrNull(index)
}

@Serializable
data class WatchHistoryItemSnapshot(
    val videoCode: String,
    val title: String,
    val coverUrl: String?,
    val watchedAtEpochMillis: Long,
    val playbackPositionMillis: Long,
)

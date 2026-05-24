package com.yenaly.han1meviewer.shared.history

import kotlinx.serialization.Serializable

class WatchHistoryFeature(
    private val store: WatchHistoryStore,
) {
    fun loadRecent(): WatchHistorySnapshot {
        return WatchHistorySnapshot(
            items = store.recent().map { item ->
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

    fun delete(videoCode: String): WatchHistorySnapshot {
        store.delete(videoCode)
        return loadRecent()
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

package com.yenaly.han1meviewer.shared.model

import kotlin.jvm.JvmInline
import kotlinx.serialization.Serializable

@JvmInline
@Serializable
value class UserVideoListType(val path: String) {
    companion object {
        val WatchLater = UserVideoListType("saves")
        val Favorites = UserVideoListType("likes")
    }
}

@Serializable
data class UserVideoListPage(
    val items: List<HanimeInfo>,
    val listDescription: String?,
    val csrfToken: String?,
    val page: Int,
    val hasNext: Boolean,
)

@Serializable
enum class OnlineWatchHistorySort(val value: String) {
    Latest("latest"),
    Popular("popular"),
    Oldest("oldest"),
}

@Serializable
data class UserPlaylistPage(
    val playlists: List<UserPlaylist>,
    val csrfToken: String?,
    val page: Int,
    val hasNext: Boolean,
)

@Serializable
data class UserPlaylist(
    val listCode: String,
    val title: String,
    val total: Int,
    val coverUrl: String?,
)

@Serializable
data class WatchHistoryItem(
    val videoCode: String,
    val title: String,
    val coverUrl: String?,
    val watchedAtEpochMillis: Long,
    val playbackPositionMillis: Long,
    val releaseDateEpochMillis: Long = 0L,
)

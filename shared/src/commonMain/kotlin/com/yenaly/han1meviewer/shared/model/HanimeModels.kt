package com.yenaly.han1meviewer.shared.model

import kotlinx.serialization.Serializable
import kotlinx.datetime.LocalDate
import kotlin.time.Clock
import kotlin.time.ExperimentalTime

@Serializable
data class HanimeInfo(
    val title: String,
    val videoCode: String?,
    val coverUrl: String?,
    val detailUrl: String?,
    val duration: String? = null,
    val views: String? = null,
    val uploadTime: String? = null,
    val genre: String? = null,
    val reviews: String? = null,
    val currentArtist: String? = null,
    val watched: Boolean = false,
    val isPlaying: Boolean = false,
    val itemType: HanimeItemType = HanimeItemType.Normal,
)

@Serializable
enum class HanimeItemType {
    Normal,
    Simplified,
}

@Serializable
data class HomePage(
    val csrfToken: String?,
    val avatarUrl: String?,
    val username: String?,
    val banner: HomeBanner?,
    val sections: List<HomeSection>,
    val userId: String?,
    val capturedAtEpochMillis: Long = currentEpochMillis(),
)

@OptIn(ExperimentalTime::class)
private fun currentEpochMillis(): Long = Clock.System.now().toEpochMilliseconds()

@Serializable
data class HomeBanner(
    val title: String,
    val description: String?,
    val imageUrl: String,
    val videoCode: String?,
)

@Serializable
data class HomeSection(
    val key: String,
    val title: String,
    val items: List<HanimeInfo>,
)

@Serializable
data class HanimeVideo(
    val videoCode: String,
    val title: String,
    val coverUrl: String?,
    val chineseTitle: String?,
    val description: String?,
    val uploadTime: LocalDate?,
    val views: String?,
    val tags: List<String>,
    val sources: List<PlaybackSource>,
    val myList: VideoMyList? = null,
    val playlist: VideoPlaylist? = null,
    val relatedHanimes: List<HanimeInfo> = emptyList(),
    val artist: Artist? = null,
    val favTimes: Int? = null,
    val isFav: Boolean = false,
    val csrfToken: String? = null,
    val currentUserId: String? = null,
    val originalComic: String? = null,
)

@Serializable
data class PlaybackSource(
    val label: String,
    val url: String,
    val contentType: String? = null,
    val isDefault: Boolean = false,
)

@Serializable
data class VideoMyList(
    val isWatchLater: Boolean,
    val items: List<VideoMyListItem>,
)

@Serializable
data class VideoMyListItem(
    val code: String,
    val title: String,
    val isSelected: Boolean,
)

@Serializable
data class VideoPlaylist(
    val name: String?,
    val videos: List<HanimeInfo>,
)

@Serializable
data class Artist(
    val name: String,
    val avatarUrl: String,
    val genre: String,
    val subscription: ArtistSubscription? = null,
)

@Serializable
data class ArtistSubscription(
    val userId: String,
    val artistId: String,
    val isSubscribed: Boolean,
)

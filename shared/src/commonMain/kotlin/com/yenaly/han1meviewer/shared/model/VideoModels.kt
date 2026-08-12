package com.yenaly.han1meviewer.shared.model

import kotlinx.datetime.LocalDate
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient

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
    @Transient
    val myList: VideoMyList? = null,
    @Transient
    val playlist: VideoPlaylist? = null,
    @Transient
    val relatedHanimes: List<HanimeInfo> = emptyList(),
    val artist: Artist? = null,
    @Transient
    val favTimes: Int? = null,
    @Transient
    val isFav: Boolean = false,
    @Transient
    val csrfToken: String? = null,
    @Transient
    val currentUserId: String? = null,
    @Transient
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

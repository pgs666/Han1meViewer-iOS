package com.yenaly.han1meviewer.shared.following

import com.yenaly.han1meviewer.shared.repository.FollowingRepository
import kotlinx.serialization.Serializable

class FollowingFeature(
    private val repository: FollowingRepository,
) {
    suspend fun loadFollowing(page: Int): FollowingSnapshot {
        val subscriptions = repository.getSubscriptions(page)
        return FollowingSnapshot(
            page = page,
            hasNext = page < subscriptions.maxPage,
            authRequired = subscriptions.authRequired,
            artists = subscriptions.subscriptions.map { artist ->
                FollowingArtistSnapshot(
                    name = artist.artistName,
                    avatarUrl = artist.avatarUrl,
                )
            },
            videos = subscriptions.subscriptionVideos.map { video ->
                FollowingVideoSnapshot(
                    videoCode = video.videoCode,
                    title = video.title,
                    coverUrl = video.coverUrl,
                    duration = video.duration,
                    views = video.views,
                    reviews = video.reviews,
                    artist = video.currentArtist,
                    uploadTime = video.uploadTime,
                )
            },
        )
    }
}

@Serializable
data class FollowingSnapshot(
    val page: Int,
    val hasNext: Boolean,
    val authRequired: Boolean = false,
    private val artists: List<FollowingArtistSnapshot>,
    private val videos: List<FollowingVideoSnapshot>,
) {
    fun artistCount(): Int = artists.size

    fun artistAt(index: Int): FollowingArtistSnapshot? = artists.getOrNull(index)

    fun videoCount(): Int = videos.size

    fun videoAt(index: Int): FollowingVideoSnapshot? = videos.getOrNull(index)
}

@Serializable
data class FollowingArtistSnapshot(
    val name: String,
    val avatarUrl: String,
)

@Serializable
data class FollowingVideoSnapshot(
    val videoCode: String,
    val title: String,
    val coverUrl: String,
    val duration: String?,
    val views: String?,
    val reviews: String?,
    val artist: String?,
    val uploadTime: String?,
)

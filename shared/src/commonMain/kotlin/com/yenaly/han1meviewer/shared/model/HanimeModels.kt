package com.yenaly.han1meviewer.shared.model

import com.yenaly.han1meviewer.shared.util.currentEpochMillis
import kotlinx.serialization.Serializable
import kotlinx.datetime.LocalDate

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
data class MySubscriptions(
    val subscriptions: List<SubscriptionItem>,
    val subscriptionVideos: List<SubscriptionVideoItem>,
    val maxPage: Int,
    val authRequired: Boolean = false,
)

@Serializable
enum class UserVideoListType(val path: String) {
    WatchLater("saves"),
    Favorites("likes"),
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
data class SubscriptionItem(
    val artistName: String,
    val avatarUrl: String,
)

@Serializable
data class SubscriptionVideoItem(
    val title: String,
    val coverUrl: String,
    val videoCode: String,
    val duration: String? = null,
    val views: String? = null,
    val reviews: String? = null,
    val currentArtist: String? = null,
    val uploadTime: String? = null,
)

@Serializable
data class WatchHistoryItem(
    val videoCode: String,
    val title: String,
    val coverUrl: String?,
    val watchedAtEpochMillis: Long,
    val playbackPositionMillis: Long,
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

@Serializable
enum class CommentTargetType(val value: String) {
    Video("video"),
    Preview("preview"),
}

@Serializable
enum class CommentPlace(val value: String) {
    Comment("comment"),
    ChildComment("reply"),
}

@Serializable
data class VideoComments(
    val comments: List<VideoComment>,
    val currentUserId: String? = null,
    val csrfToken: String? = null,
)

@Serializable
data class VideoComment(
    val avatarUrl: String,
    val username: String,
    val date: String,
    val content: String,
    val thumbUp: Int?,
    val isChildComment: Boolean,
    val hasMoreReplies: Boolean = false,
    val replyCount: Int? = 0,
    val id: String? = null,
    val post: VideoCommentPost,
    val redirectUrl: String? = null,
    val reportableId: String? = null,
    val reportableType: String? = null,
) {
    val replyTargetIdOrNull: String?
        get() = post.foreignId ?: id

    val stableKey: String
        get() = replyTargetIdOrNull
            ?: reportableId
            ?: "$username|$date|${content.hashCode()}"

    fun withLikeResult(isPositive: Boolean): VideoComment {
        val currentLikes = thumbUp ?: return this
        return if (isPositive) {
            val cancel = post.likeCommentStatus
            copy(
                thumbUp = currentLikes + if (cancel) -1 else 1,
                post = post.copy(
                    isPositive = true,
                    likeCommentStatus = !cancel,
                    unlikeCommentStatus = false,
                ),
            )
        } else {
            val cancel = post.unlikeCommentStatus
            copy(
                thumbUp = currentLikes - if (cancel) -1 else 1,
                post = post.copy(
                    isPositive = false,
                    likeCommentStatus = false,
                    unlikeCommentStatus = !cancel,
                ),
            )
        }
    }
}

@Serializable
data class VideoCommentPost(
    val foreignId: String? = null,
    val isPositive: Boolean = false,
    val likeUserId: String? = null,
    val commentLikesCount: Int? = null,
    val commentLikesSum: Int? = null,
    val likeCommentStatus: Boolean = false,
    val unlikeCommentStatus: Boolean = false,
)

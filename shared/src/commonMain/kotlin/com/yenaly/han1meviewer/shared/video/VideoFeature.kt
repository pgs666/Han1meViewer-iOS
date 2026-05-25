package com.yenaly.han1meviewer.shared.video

import com.yenaly.han1meviewer.shared.history.WatchHistoryStore
import com.yenaly.han1meviewer.shared.repository.VideoRepository
import kotlinx.serialization.Serializable
import kotlin.time.Clock
import kotlin.time.ExperimentalTime

class VideoFeature(
    private val repository: VideoRepository,
    private val watchHistoryStore: WatchHistoryStore? = null,
) {
    @OptIn(ExperimentalTime::class)
    @Throws(Exception::class)
    suspend fun loadVideo(videoCode: String): VideoDetailSnapshot {
        val video = repository.getVideo(videoCode)
        val defaultSource = video.sources.firstOrNull { source -> source.isDefault }
            ?: video.sources.firstOrNull()
        val playbackPositionMillis = watchHistoryStore
            ?.find(video.videoCode)
            ?.playbackPositionMillis
            ?: 0L

        watchHistoryStore?.record(
            videoCode = video.videoCode,
            title = video.title.ifBlank { "Untitled" },
            coverUrl = video.coverUrl,
            watchedAtEpochMillis = Clock.System.now().toEpochMilliseconds(),
            playbackPositionMillis = playbackPositionMillis,
        )

        return VideoDetailSnapshot(
            videoCode = video.videoCode,
            title = video.title.ifBlank { "Untitled" },
            chineseTitle = video.chineseTitle,
            videoDescription = video.description,
            coverUrl = video.coverUrl,
            views = video.views,
            tagSummary = video.tags.take(6).joinToString(separator = ", "),
            sourceCount = video.sources.size,
            defaultSourceLabel = defaultSource?.label,
            defaultSourceUrl = defaultSource?.url,
            artistName = video.artist?.name,
            artistAvatarUrl = video.artist?.avatarUrl,
            artistGenre = video.artist?.genre,
            isArtistSubscribed = video.artist?.subscription?.isSubscribed ?: false,
            artistSubscriptionUserId = video.artist?.subscription?.userId,
            artistSubscriptionArtistId = video.artist?.subscription?.artistId,
            favTimes = video.favTimes,
            isFav = video.isFav,
            csrfToken = video.csrfToken,
            currentUserId = video.currentUserId,
            isWatchLater = video.myList?.isWatchLater ?: false,
            originalComic = video.originalComic,
            playbackPositionMillis = playbackPositionMillis,
            playbackSources = video.sources.map { source ->
                VideoPlaybackSourceSnapshot(
                    label = source.label,
                    url = source.url,
                    contentType = source.contentType,
                    isDefault = source == defaultSource,
                )
            },
            uploadDate = video.uploadTime?.toString(),
            tags = video.tags,
            playlistName = video.playlist?.name,
            playlistVideos = video.playlist?.videos.orEmpty().mapNotNull { item ->
                val playlistVideoCode = item.videoCode ?: return@mapNotNull null
                VideoRelatedSnapshot(
                    videoCode = playlistVideoCode,
                    title = item.title,
                    coverUrl = item.coverUrl,
                    duration = item.duration,
                    views = item.views,
                    artist = item.currentArtist,
                    uploadTime = item.uploadTime,
                    isPlaying = item.isPlaying,
                )
            },
            myListItems = video.myList?.items.orEmpty().map { item ->
                VideoMyListItemSnapshot(
                    code = item.code,
                    title = item.title,
                    isSelected = item.isSelected,
                )
            },
            relatedVideos = video.relatedHanimes.mapNotNull { item ->
                val relatedVideoCode = item.videoCode ?: return@mapNotNull null
                VideoRelatedSnapshot(
                    videoCode = relatedVideoCode,
                    title = item.title,
                    coverUrl = item.coverUrl,
                    duration = item.duration,
                    views = item.views,
                    artist = item.currentArtist,
                    uploadTime = item.uploadTime,
                    isPlaying = item.isPlaying,
                )
            },
        )
    }

    @OptIn(ExperimentalTime::class)
    fun recordPlaybackPosition(
        videoCode: String,
        title: String,
        coverUrl: String?,
        playbackPositionMillis: Long,
    ) {
        watchHistoryStore?.record(
            videoCode = videoCode,
            title = title.ifBlank { "Untitled" },
            coverUrl = coverUrl,
            watchedAtEpochMillis = Clock.System.now().toEpochMilliseconds(),
            playbackPositionMillis = playbackPositionMillis.coerceAtLeast(0L),
        )
    }

    @Throws(Exception::class)
    suspend fun setFavorite(
        videoCode: String,
        currentUserId: String?,
        csrfToken: String?,
        isFavorite: Boolean,
    ) {
        repository.setFavorite(
            videoCode = videoCode,
            userId = currentUserId,
            csrfToken = csrfToken,
            isFavorite = isFavorite,
        )
    }

    @Throws(Exception::class)
    suspend fun setMyListItem(
        listCode: String,
        videoCode: String,
        csrfToken: String?,
        isSelected: Boolean,
    ) {
        repository.setMyListItem(
            listCode = listCode,
            videoCode = videoCode,
            csrfToken = csrfToken,
            isSelected = isSelected,
        )
    }

    @Throws(Exception::class)
    suspend fun setArtistSubscription(
        userId: String,
        artistId: String,
        csrfToken: String?,
        isSubscribed: Boolean,
    ) {
        repository.setArtistSubscription(
            userId = userId,
            artistId = artistId,
            csrfToken = csrfToken,
            isSubscribed = isSubscribed,
        )
    }
}

@Serializable
data class VideoDetailSnapshot(
    val videoCode: String,
    val title: String,
    val chineseTitle: String?,
    val videoDescription: String?,
    val coverUrl: String?,
    val views: String?,
    val tagSummary: String,
    val sourceCount: Int,
    val defaultSourceLabel: String?,
    val defaultSourceUrl: String?,
    val artistName: String?,
    val artistAvatarUrl: String?,
    val artistGenre: String?,
    val isArtistSubscribed: Boolean,
    val artistSubscriptionUserId: String?,
    val artistSubscriptionArtistId: String?,
    val favTimes: Int?,
    val isFav: Boolean,
    val csrfToken: String?,
    val currentUserId: String?,
    val isWatchLater: Boolean,
    val originalComic: String?,
    val playbackPositionMillis: Long,
    private val playbackSources: List<VideoPlaybackSourceSnapshot>,
    val uploadDate: String?,
    private val tags: List<String>,
    val playlistName: String?,
    private val playlistVideos: List<VideoRelatedSnapshot>,
    private val myListItems: List<VideoMyListItemSnapshot>,
    private val relatedVideos: List<VideoRelatedSnapshot>,
) {
    val hasPlayableSource: Boolean
        get() = !defaultSourceUrl.isNullOrBlank()

    fun relatedVideoCount(): Int = relatedVideos.size

    fun relatedVideoAt(index: Int): VideoRelatedSnapshot? = relatedVideos.getOrNull(index)

    fun playbackSourceCount(): Int = playbackSources.size

    fun playbackSourceAt(index: Int): VideoPlaybackSourceSnapshot? = playbackSources.getOrNull(index)

    fun tagCount(): Int = tags.size

    fun tagAt(index: Int): String? = tags.getOrNull(index)

    fun playlistVideoCount(): Int = playlistVideos.size

    fun playlistVideoAt(index: Int): VideoRelatedSnapshot? = playlistVideos.getOrNull(index)

    fun myListItemCount(): Int = myListItems.size

    fun myListItemAt(index: Int): VideoMyListItemSnapshot? = myListItems.getOrNull(index)
}

@Serializable
data class VideoPlaybackSourceSnapshot(
    val label: String,
    val url: String,
    val contentType: String?,
    val isDefault: Boolean,
)

@Serializable
data class VideoRelatedSnapshot(
    val videoCode: String,
    val title: String,
    val coverUrl: String?,
    val duration: String?,
    val views: String?,
    val artist: String?,
    val uploadTime: String?,
    val isPlaying: Boolean = false,
)

@Serializable
data class VideoMyListItemSnapshot(
    val code: String,
    val title: String,
    val isSelected: Boolean,
)

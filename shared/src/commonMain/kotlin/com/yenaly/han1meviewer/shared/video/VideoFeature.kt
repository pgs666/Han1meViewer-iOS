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
    suspend fun loadVideo(videoCode: String): VideoDetailSnapshot {
        val video = repository.getVideo(videoCode)
        val defaultSource = video.sources.firstOrNull { source -> source.isDefault }
            ?: video.sources.firstOrNull()

        watchHistoryStore?.record(
            videoCode = video.videoCode,
            title = video.title.ifBlank { "Untitled" },
            coverUrl = video.coverUrl,
            watchedAtEpochMillis = Clock.System.now().toEpochMilliseconds(),
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
            uploadDate = video.uploadTime?.toString(),
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
    val uploadDate: String?,
) {
    val hasPlayableSource: Boolean
        get() = !defaultSourceUrl.isNullOrBlank()
}

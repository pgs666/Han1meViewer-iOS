package com.yenaly.han1meviewer.shared.video

import com.yenaly.han1meviewer.shared.model.PlaybackSource
import com.yenaly.han1meviewer.shared.repository.KtorVideoRepository
import kotlinx.serialization.Serializable

class VideoFeature {
    private val repository = KtorVideoRepository()

    suspend fun loadVideo(videoCode: String): VideoDetailSnapshot {
        val video = repository.getVideo(videoCode)
        val defaultSource = video.sources.firstOrNull { source -> source.isDefault }
            ?: video.sources.firstOrNull()

        return VideoDetailSnapshot(
            videoCode = video.videoCode,
            title = video.title.ifBlank { "Untitled" },
            chineseTitle = video.chineseTitle,
            description = video.description,
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
    val description: String?,
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

package com.yenaly.han1meviewer.shared.history

import com.yenaly.han1meviewer.shared.model.OnlineWatchHistorySort
import com.yenaly.han1meviewer.shared.repository.HomeRepository
import com.yenaly.han1meviewer.shared.repository.OnlineWatchHistoryRepository
import kotlinx.serialization.Serializable

class OnlineWatchHistoryFeature(
    private val homeRepository: HomeRepository,
    private val historyRepository: OnlineWatchHistoryRepository,
) {
    suspend fun loadLatest(page: Int): OnlineWatchHistorySnapshot {
        return load(OnlineWatchHistorySort.Latest, page)
    }

    suspend fun loadOldest(page: Int): OnlineWatchHistorySnapshot {
        return load(OnlineWatchHistorySort.Oldest, page)
    }

    suspend fun load(sort: OnlineWatchHistorySort, page: Int): OnlineWatchHistorySnapshot {
        val userId = homeRepository.getHomePage().userId
            ?: return OnlineWatchHistorySnapshot.authRequired(page)
        val pageData = historyRepository.getHistories(userId, sort, page)

        return OnlineWatchHistorySnapshot(
            page = pageData.page,
            hasNext = pageData.hasNext,
            csrfToken = pageData.csrfToken,
            authRequired = false,
            videos = pageData.items.mapNotNull { info ->
                val videoCode = info.videoCode ?: return@mapNotNull null
                OnlineWatchHistoryItemSnapshot(
                    videoCode = videoCode,
                    title = info.title,
                    coverUrl = info.coverUrl,
                    duration = info.duration,
                    views = info.views,
                    artist = info.currentArtist,
                    uploadTime = info.uploadTime,
                )
            },
        )
    }

    suspend fun remove(videoCode: String, csrfToken: String?): OnlineWatchHistoryMutationSnapshot {
        historyRepository.removeHistoryItem(videoCode, csrfToken)
        return OnlineWatchHistoryMutationSnapshot(videoCode = videoCode)
    }
}

@Serializable
data class OnlineWatchHistorySnapshot(
    val page: Int,
    val hasNext: Boolean,
    val csrfToken: String?,
    val authRequired: Boolean = false,
    private val videos: List<OnlineWatchHistoryItemSnapshot>,
) {
    fun videoCount(): Int = videos.size

    fun videoAt(index: Int): OnlineWatchHistoryItemSnapshot? = videos.getOrNull(index)

    companion object {
        fun authRequired(page: Int): OnlineWatchHistorySnapshot {
            return OnlineWatchHistorySnapshot(
                page = page,
                hasNext = false,
                csrfToken = null,
                authRequired = true,
                videos = emptyList(),
            )
        }
    }
}

@Serializable
data class OnlineWatchHistoryItemSnapshot(
    val videoCode: String,
    val title: String,
    val coverUrl: String?,
    val duration: String?,
    val views: String?,
    val artist: String?,
    val uploadTime: String?,
)

@Serializable
data class OnlineWatchHistoryMutationSnapshot(
    val videoCode: String,
)

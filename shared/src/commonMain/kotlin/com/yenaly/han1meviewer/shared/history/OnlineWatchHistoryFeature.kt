package com.yenaly.han1meviewer.shared.history

import com.yenaly.han1meviewer.shared.model.OnlineWatchHistorySort
import com.yenaly.han1meviewer.shared.repository.OnlineWatchHistoryRepository
import kotlinx.serialization.Serializable

class OnlineWatchHistoryFeature(
    private val currentUserIdProvider: suspend () -> String?,
    private val historyRepository: OnlineWatchHistoryRepository,
) {
    @Throws(Exception::class)
    suspend fun loadLatest(page: Int): OnlineWatchHistorySnapshot {
        return load(OnlineWatchHistorySort.Latest, page)
    }

    @Throws(Exception::class)
    suspend fun loadOldest(page: Int): OnlineWatchHistorySnapshot {
        return load(OnlineWatchHistorySort.Oldest, page)
    }

    @Throws(Exception::class)
    suspend fun loadPopular(page: Int): OnlineWatchHistorySnapshot {
        return load(OnlineWatchHistorySort.Popular, page)
    }

    @Throws(Exception::class)
    suspend fun load(sort: OnlineWatchHistorySort, page: Int): OnlineWatchHistorySnapshot {
        val userId = currentUserIdProvider()
            ?: return OnlineWatchHistorySnapshot.authRequired(page)
        val pageData = historyRepository.getHistories(userId, sort, page)

        return OnlineWatchHistorySnapshot(
            page = pageData.page,
            hasNext = pageData.hasNext,
            csrfToken = pageData.csrfToken,
            authRequired = false,
            videos = pageData.items.map { info ->
                OnlineWatchHistoryItemSnapshot(
                    videoCode = info.videoCode,
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

    @Throws(Exception::class)
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

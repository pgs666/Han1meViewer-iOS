package com.yenaly.han1meviewer.shared.search

import com.yenaly.han1meviewer.shared.model.SearchParams
import com.yenaly.han1meviewer.shared.repository.SearchRepository
import kotlinx.serialization.Serializable
import kotlin.time.Clock
import kotlin.time.ExperimentalTime

class SearchFeature(
    private val repository: SearchRepository,
    private val historyStore: SearchHistoryStore? = null,
) {
    @OptIn(ExperimentalTime::class)
    suspend fun search(keyword: String, page: Int): SearchSnapshot {
        val trimmedKeyword = keyword.trim()
        val result = repository.search(SearchParams(keyword = trimmedKeyword), page)
        if (page == 1 && trimmedKeyword.isNotBlank()) {
            historyStore?.record(
                keyword = trimmedKeyword,
                searchedAtEpochMillis = Clock.System.now().toEpochMilliseconds(),
            )
        }
        val items = result.items.mapNotNull { item ->
            val videoCode = item.videoCode ?: return@mapNotNull null
            SearchVideoSnapshot(
                videoCode = videoCode,
                title = item.title,
                coverUrl = item.coverUrl,
                duration = item.duration,
                views = item.views,
                uploadTime = item.uploadTime,
                artist = item.currentArtist,
            )
        }

        return SearchSnapshot(
            items = items,
            page = result.page,
            hasNext = result.hasNext,
        )
    }

    fun recentHistory(limit: Int): SearchHistorySnapshot {
        val keywords = historyStore
            ?.recent(limit = (limit * HISTORY_DEDUP_FACTOR).toLong())
            .orEmpty()
            .map { item -> item.keyword.trim() }
            .filter { keyword -> keyword.isNotBlank() }
            .distinct()
            .take(limit)

        return SearchHistorySnapshot(keywords = keywords)
    }

    fun clearHistory(): SearchHistorySnapshot {
        historyStore?.clear()
        return SearchHistorySnapshot(keywords = emptyList())
    }

    private companion object {
        const val HISTORY_DEDUP_FACTOR = 3
    }
}

@Serializable
data class SearchSnapshot(
    private val items: List<SearchVideoSnapshot>,
    val page: Int,
    val hasNext: Boolean,
) {
    fun itemCount(): Int = items.size

    fun itemAt(index: Int): SearchVideoSnapshot? = items.getOrNull(index)
}

@Serializable
data class SearchVideoSnapshot(
    val videoCode: String,
    val title: String,
    val coverUrl: String?,
    val duration: String?,
    val views: String?,
    val uploadTime: String?,
    val artist: String?,
)

@Serializable
data class SearchHistorySnapshot(
    private val keywords: List<String>,
) {
    fun keywordCount(): Int = keywords.size

    fun keywordAt(index: Int): String? = keywords.getOrNull(index)
}

package com.yenaly.han1meviewer.shared.search

import com.yenaly.han1meviewer.shared.model.SearchParams
import com.yenaly.han1meviewer.shared.repository.SearchRepository
import com.yenaly.han1meviewer.shared.util.currentEpochMillis
import kotlinx.serialization.Serializable

class SearchFeature(
    private val repository: SearchRepository,
    private val historyStore: SearchHistoryStore? = null,
) {
    @Throws(Exception::class)
    suspend fun search(keyword: String, page: Int): SearchSnapshot {
        val trimmedKeyword = keyword.trim()
        return search(SearchParams(keyword = trimmedKeyword), page, filterSummary = "")
    }

    @Throws(Exception::class)
    suspend fun searchAdvanced(
        keyword: String,
        genre: String?,
        sort: String?,
        broad: Boolean,
        releaseDate: String?,
        duration: String?,
        tags: String,
        brands: String,
        filterSummary: String,
        page: Int,
        recordHistory: Boolean,
    ): SearchSnapshot {
        return search(
            params = SearchParams(
                keyword = keyword.trim(),
                genre = genre?.takeIf { it.isNotBlank() && it != ALL_OPTION_KEY },
                sort = sort?.takeIf { it.isNotBlank() },
                broad = broad,
                releaseDate = releaseDate?.takeIf { it.isNotBlank() },
                duration = duration?.takeIf { it.isNotBlank() },
                tags = tags.toSearchKeyList(),
                brands = brands.toSearchKeyList(),
            ),
            page = page,
            filterSummary = filterSummary.trim(),
            recordHistory = recordHistory,
        )
    }

    private suspend fun search(
        params: SearchParams,
        page: Int,
        filterSummary: String,
        recordHistory: Boolean = true,
    ): SearchSnapshot {
        val result = repository.search(params, page)
        val trimmedKeyword = params.keyword.trim()
        if (recordHistory && page == 1 && (trimmedKeyword.isNotBlank() || filterSummary.isNotBlank())) {
            historyStore?.record(
                keyword = trimmedKeyword,
                filterSummary = filterSummary,
                searchedAtEpochMillis = currentEpochMillis(),
            )
        }
        val items = result.items.map { item ->
            SearchVideoSnapshot(
                videoCode = item.videoCode,
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

    private fun String.toSearchKeyList(): List<String> {
        return lineSequence()
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()
            .toList()
    }

    fun recentHistory(limit: Int): SearchHistorySnapshot {
        val items = historyStore
            ?.recent(limit = (limit * HISTORY_DEDUP_FACTOR).toLong())
            .orEmpty()
            .map { item ->
                SearchHistoryEntrySnapshot(
                    keyword = item.keyword.trim(),
                    filterSummary = item.filterSummary.trim(),
                )
            }
            .filter { item -> item.keyword.isNotBlank() || item.filterSummary.isNotBlank() }
            .distinctBy { item -> "${item.keyword}\n${item.filterSummary}" }
            .take(limit)

        return SearchHistorySnapshot(items = items)
    }

    fun clearHistory(): SearchHistorySnapshot {
        historyStore?.clear()
        return SearchHistorySnapshot(items = emptyList())
    }

    private companion object {
        const val HISTORY_DEDUP_FACTOR = 3
        const val ALL_OPTION_KEY = "全部"
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
    private val items: List<SearchHistoryEntrySnapshot>,
) {
    fun itemCount(): Int = items.size

    fun itemAt(index: Int): SearchHistoryEntrySnapshot? = items.getOrNull(index)

    fun keywordCount(): Int = items.size

    fun keywordAt(index: Int): String? = items.getOrNull(index)?.keyword
}

@Serializable
data class SearchHistoryEntrySnapshot(
    val keyword: String,
    val filterSummary: String,
)

package com.yenaly.han1meviewer.shared.search

import com.yenaly.han1meviewer.shared.model.SearchParams
import com.yenaly.han1meviewer.shared.repository.SearchRepository
import kotlinx.serialization.Serializable

class SearchFeature(
    private val repository: SearchRepository,
) {
    suspend fun search(keyword: String, page: Int): SearchSnapshot {
        val trimmedKeyword = keyword.trim()
        val result = repository.search(SearchParams(keyword = trimmedKeyword), page)
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
        )
    }
}

@Serializable
data class SearchSnapshot(
    private val items: List<SearchVideoSnapshot>,
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

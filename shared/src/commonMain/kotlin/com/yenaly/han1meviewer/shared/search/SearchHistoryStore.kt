package com.yenaly.han1meviewer.shared.search

import com.yenaly.han1meviewer.shared.db.Han1meDatabase

class SearchHistoryStore(
    private val database: Han1meDatabase,
) {
    fun recent(limit: Long): List<SearchHistoryItem> {
        return database.searchHistoryQueries.selectRecent(limit, ::mapHistoryItem).executeAsList()
    }

    fun record(keyword: String, searchedAtEpochMillis: Long) {
        database.searchHistoryQueries.insert(
            keyword = keyword,
            searched_at_epoch_millis = searchedAtEpochMillis,
        )
    }

    fun clear() {
        database.searchHistoryQueries.deleteAll()
    }

    private fun mapHistoryItem(
        id: Long,
        keyword: String,
        searchedAtEpochMillis: Long,
    ): SearchHistoryItem {
        return SearchHistoryItem(
            id = id,
            keyword = keyword,
            searchedAtEpochMillis = searchedAtEpochMillis,
        )
    }
}

data class SearchHistoryItem(
    val id: Long,
    val keyword: String,
    val searchedAtEpochMillis: Long,
)

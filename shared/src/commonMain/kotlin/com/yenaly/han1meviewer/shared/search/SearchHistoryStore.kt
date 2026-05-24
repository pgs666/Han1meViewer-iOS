package com.yenaly.han1meviewer.shared.search

import com.yenaly.han1meviewer.shared.db.Han1meDatabase

class SearchHistoryStore(
    private val database: Han1meDatabase,
) {
    fun recent(limit: Long): List<SearchHistoryItem> {
        return database.searchHistoryQueries.selectRecent(limit, ::mapHistoryItem).executeAsList()
    }

    fun record(keyword: String, filterSummary: String, searchedAtEpochMillis: Long) {
        database.searchHistoryQueries.insert(
            keyword = encodeHistoryValue(keyword, filterSummary),
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
        val decoded = decodeHistoryValue(keyword)
        return SearchHistoryItem(
            id = id,
            keyword = decoded.first,
            filterSummary = decoded.second,
            searchedAtEpochMillis = searchedAtEpochMillis,
        )
    }

    private fun encodeHistoryValue(keyword: String, filterSummary: String): String {
        if (filterSummary.isBlank()) return keyword
        return "$HISTORY_VALUE_PREFIX$keyword$HISTORY_VALUE_SEPARATOR$filterSummary"
    }

    private fun decodeHistoryValue(rawValue: String): Pair<String, String> {
        if (!rawValue.startsWith(HISTORY_VALUE_PREFIX)) return rawValue to ""
        val payload = rawValue.removePrefix(HISTORY_VALUE_PREFIX)
        val parts = payload.split(HISTORY_VALUE_SEPARATOR, limit = 2)
        return parts.getOrElse(0) { "" } to parts.getOrElse(1) { "" }
    }

    private companion object {
        const val HISTORY_VALUE_PREFIX = "han1me-search-v2:"
        const val HISTORY_VALUE_SEPARATOR = "\u001F"
    }
}

data class SearchHistoryItem(
    val id: Long,
    val keyword: String,
    val filterSummary: String,
    val searchedAtEpochMillis: Long,
)

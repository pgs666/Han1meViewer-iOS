package com.yenaly.han1meviewer.shared.search

import com.yenaly.han1meviewer.shared.db.DatabaseDriverFactory
import com.yenaly.han1meviewer.shared.db.createDatabase
import kotlin.test.Test
import kotlin.test.assertEquals

class SearchHistoryStoreTest {
    @Test
    fun recordPrunesOldestItemsBeyondRetentionLimit() {
        val store = SearchHistoryStore(createDatabase(DatabaseDriverFactory()))

        repeat(101) { index ->
            store.record(
                keyword = "keyword-$index",
                filterSummary = "",
                searchedAtEpochMillis = index.toLong(),
            )
        }

        val recent = store.recent(limit = 200)

        assertEquals(100, recent.size)
        assertEquals("keyword-100", recent.first().keyword)
        assertEquals("keyword-1", recent.last().keyword)
    }
}

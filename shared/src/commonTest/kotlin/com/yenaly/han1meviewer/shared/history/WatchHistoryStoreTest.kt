package com.yenaly.han1meviewer.shared.history

import com.yenaly.han1meviewer.shared.db.DatabaseDriverFactory
import com.yenaly.han1meviewer.shared.db.createDatabase
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class WatchHistoryStoreTest {
    @Test
    fun recordPrunesOldestItemsBeyondRetentionLimit() {
        val store = WatchHistoryStore(createDatabase(DatabaseDriverFactory()))

        repeat(1_001) { index ->
            store.record(
                videoCode = "video-$index",
                title = "Video $index",
                coverUrl = null,
                watchedAtEpochMillis = index.toLong(),
            )
        }

        val recent = store.recent(limit = 2_000)

        assertEquals(1_000, recent.size)
        assertNull(store.find("video-0"))
        assertEquals("video-1000", recent.first().videoCode)
    }
}

package com.yenaly.han1meviewer.shared.download

import com.yenaly.han1meviewer.shared.db.DatabaseDriverFactory
import com.yenaly.han1meviewer.shared.db.createDatabase
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class DownloadStoreTest {
    private fun newStore() = DownloadStore(createDatabase(DatabaseDriverFactory()))

    private fun sampleItem(
        videoCode: String = "abc",
        quality: String = "1080P",
        state: Int = 0,
        downloaded: Long = 0,
        total: Long = 0,
    ) = DownloadItem(
        videoCode = videoCode,
        quality = quality,
        title = "Title $videoCode",
        coverUrl = null,
        remoteUrl = "https://example.com/$videoCode.mp4",
        localPath = "/tmp/$videoCode.mp4",
        totalBytes = total,
        downloadedBytes = downloaded,
        state = state,
        addedAtEpochMillis = 1_000,
    )

    @Test
    fun upsertAndFindRoundTrips() {
        val store = newStore()
        store.upsert(sampleItem())
        val found = store.find("abc", "1080P")
        assertEquals("abc", found?.videoCode)
        assertEquals("1080P", found?.quality)
    }

    @Test
    fun sameVideoDifferentQualityCoexist() {
        val store = newStore()
        store.upsert(sampleItem(quality = "1080P"))
        store.upsert(sampleItem(quality = "720P"))
        assertEquals(2, store.all().size)
    }

    @Test
    fun updateProgressPersists() {
        val store = newStore()
        store.upsert(sampleItem())
        store.updateProgress("abc", "1080P", downloadedBytes = 500, totalBytes = 1_000, state = 1)
        val found = store.find("abc", "1080P")
        assertEquals(500, found?.downloadedBytes)
        assertEquals(1_000, found?.totalBytes)
        assertEquals(1, found?.state)
    }

    @Test
    fun deleteRemovesRow() {
        val store = newStore()
        store.upsert(sampleItem())
        store.delete("abc", "1080P")
        assertNull(store.find("abc", "1080P"))
    }
}

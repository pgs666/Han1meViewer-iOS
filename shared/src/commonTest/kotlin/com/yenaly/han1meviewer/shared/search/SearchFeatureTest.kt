package com.yenaly.han1meviewer.shared.search

import com.yenaly.han1meviewer.shared.model.HanimeInfo
import com.yenaly.han1meviewer.shared.model.PageResult
import com.yenaly.han1meviewer.shared.model.SearchParams
import com.yenaly.han1meviewer.shared.repository.SearchRepository
import com.yenaly.han1meviewer.shared.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class SearchFeatureTest {
    @Test
    fun artistSearchFiltersExactArtistAndSkipsEmptyPages() = runTest {
        val repository = RecordingSearchRepository()
        val feature = SearchFeature(repository)

        val result = feature.searchArtist("  Eros  ", page = 1)

        assertEquals(listOf(1, 2), repository.pages)
        assertEquals(listOf(SearchParams(keyword = "Eros"), SearchParams(keyword = "Eros")), repository.params)
        assertEquals(2, result.page)
        assertFalse(result.hasNext)
        assertEquals(1, result.itemCount())
        assertEquals("Eros", result.itemAt(0)?.artist)
    }

    @Test
    fun subscribedArtistSearchUsesCompleteSubscriptionResults() = runTest {
        val repository = RecordingSearchRepository()
        val feature = SearchFeature(repository)

        val result = feature.searchSubscribedArtist(" Eros ", page = 1)

        assertEquals(listOf("Eros"), repository.subscribedArtists)
        assertEquals(1, result.itemCount())
        assertEquals("subscribed", result.itemAt(0)?.videoCode)
    }

    private class RecordingSearchRepository : SearchRepository {
        val params = mutableListOf<SearchParams>()
        val pages = mutableListOf<Int>()
        val subscribedArtists = mutableListOf<String>()

        override suspend fun search(params: SearchParams, page: Int): PageResult<HanimeInfo> {
            this.params += params
            pages += page
            return if (page == 1) {
                PageResult(
                    items = listOf(video(code = "wrong", artist = "Eroshi3D")),
                    page = 1,
                    hasNext = true,
                )
            } else {
                PageResult(
                    items = listOf(
                        video(code = "exact", artist = "Eros"),
                        video(code = "wrong-again", artist = "Neural Desires"),
                    ),
                    page = 2,
                    hasNext = false,
                )
            }
        }

        override suspend fun searchSubscribedArtist(keyword: String, page: Int): PageResult<HanimeInfo> {
            subscribedArtists += keyword
            return PageResult(
                items = listOf(
                    video(code = "subscribed", artist = "Eros"),
                    video(code = "wrong-subscription", artist = "Eroshi3D"),
                ),
                page = page,
                hasNext = false,
            )
        }

        private fun video(code: String, artist: String) = HanimeInfo(
            title = code,
            videoCode = code,
            coverUrl = null,
            detailUrl = null,
            currentArtist = artist,
        )
    }
}

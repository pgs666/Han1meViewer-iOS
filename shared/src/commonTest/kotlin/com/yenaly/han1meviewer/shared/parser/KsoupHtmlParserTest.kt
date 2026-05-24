package com.yenaly.han1meviewer.shared.parser

import com.yenaly.han1meviewer.shared.model.HanimeItemType
import com.yenaly.han1meviewer.shared.model.SearchParams
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class KsoupHtmlParserTest {
    private val parser = KsoupHtmlParser()

    @Test
    fun parsesNormalSearchCards() {
        val html = """
            <html>
              <body>
                <div class="content-padding-new">
                  <div class="horizontal-card">
                    <a href="https://hanime1.me/watch?v=12345"></a>
                    <img src="https://img.example/cover.jpg">
                    <div class="title">Video title</div>
                    <div class="thumb-container">
                      <div class="duration">12:34</div>
                      <div class="stat-item">unused</div>
                      <div class="stat-item">1.2M</div>
                    </div>
                    <div class="subtitle"><a>Artist • 2026-05-01</a></div>
                    <div class="stats-container"><div class="stat-item">thumb_up 98%</div></div>
                  </div>
                </div>
              </body>
            </html>
        """.trimIndent()

        val result = parser.parseSearch(html, SearchParams(keyword = "video"), page = 1)

        assertTrue(result.hasNext)
        assertEquals(1, result.items.size)
        assertEquals("12345", result.items.single().videoCode)
        assertEquals("Artist", result.items.single().currentArtist)
        assertEquals(HanimeItemType.Normal, result.items.single().itemType)
    }

    @Test
    fun parsesVideoSourcesAndTags() {
        val html = """
            <html>
              <body>
                <input name="_token" value="csrf-video">
                <input name="like-user-id" value="42">
                <input name="likes-count" value="7">
                <input name="like-status" value="1">
                <h1 id="shareBtn-title">Video title</h1>
                <div class="video-details-wrapper">
                  <div>
                    <div>
                      <div>觀看次數： 1000次 2026-05-01</div>
                    </div>
                  </div>
                  <h3>中文标题</h3>
                  <div class="video-caption-text">Description</div>
                </div>
                <a class="single-video-tag" href="/search?tags=a">#Tag A (1)</a>
                <div class="single-video-tag"><a href="/search?tags=b">#Tag B (2)</a></div>
                <video id="player" poster="https://img.example/poster.jpg">
                  <source size="720" src="https://video.example/720.mp4" type="video/mp4">
                </video>
              </body>
            </html>
        """.trimIndent()

        val video = parser.parseVideo(html, videoCode = "12345")

        assertEquals("Video title", video.title)
        assertEquals("12345", video.videoCode)
        assertEquals("720P", video.sources.single().label)
        assertEquals("https://video.example/720.mp4", video.sources.single().url)
        assertEquals(listOf("Tag B"), video.tags)
        assertNotNull(video.uploadTime)
    }
}

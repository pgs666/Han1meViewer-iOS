package com.yenaly.han1meviewer.shared.parser

import com.yenaly.han1meviewer.shared.model.HanimeItemType
import com.yenaly.han1meviewer.shared.model.SearchParams
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class KsoupHtmlParserTest {
    private val parser = KsoupHtmlParser()

    @Test
    fun parseHomeUsesAndroidSectionIndexesAndBannerCommentFallback() {
        val rowHtml = (0..13).joinToString(separator = "\n") { index ->
            """
            <div>
              <div class="horizontal-card">
                <a href="/watch?v=${1000 + index}"></a>
                <img src="/covers/$index.jpg">
                <div class="title">Video $index</div>
              </div>
            </div>
            """.trimIndent()
        }
        val html = """
            <html>
              <body>
                <div id="user-modal-dp-wrapper">
                  <img src="/avatar.jpg">
                  <div id="user-modal-name">Alice</div>
                </div>
                <a id="user-modal-trigger" href="/user/42"></a>
                <div>
                  <img src="/ignored.jpg">
                  <img src="/banner.jpg" alt="Banner title">
                </div>
                <div id="home-banner-wrapper">
                  <h4>Banner description</h4>
                  <!-- /watch?v=9999 -->
                </div>
                <div id="home-rows-wrapper">
                  $rowHtml
                </div>
              </body>
            </html>
        """.trimIndent()

        val home = parser.parseHome(html)

        assertEquals("9999", home.banner?.videoCode)
        assertEquals(
            listOf(
                "latestRelease",
                "latestHanime",
                "ecchiAnime",
                "shortEpisodeAnime",
                "motionAnime",
                "threeDCG",
                "twoPointFiveDAnime",
                "twoDAnime",
                "aiGenerated",
                "mmd",
                "cosplay",
                "watchingNow",
            ),
            home.sections.map { it.key },
        )
        assertEquals("1005", home.sections.first { it.key == "motionAnime" }.items.single().videoCode)
        assertEquals("1010", home.sections.first { it.key == "aiGenerated" }.items.single().videoCode)
    }

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
                <ul class="pagination">
                  <li><a class="page-link" href="/search?page=1">1</a></li>
                  <li><a class="page-link" href="/search?page=2">2</a></li>
                </ul>
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
    fun treatsPageWithoutPaginationAsLastPage() {
        val html = """
            <html>
              <body>
                <div class="content-padding-new">
                  <div class="horizontal-card">
                    <a href="https://hanime1.me/watch?v=12345"></a>
                    <img src="https://img.example/cover.jpg">
                    <div class="title">Video title</div>
                  </div>
                </div>
              </body>
            </html>
        """.trimIndent()

        val result = parser.parseSearch(html, SearchParams(keyword = "video"), page = 1)

        assertEquals(false, result.hasNext)
        assertEquals(1, result.items.size)
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
        assertEquals("1000", video.views)
        assertEquals(true, video.isFav)
        assertEquals(listOf("Tag B"), video.tags)
        assertNotNull(video.uploadTime)
    }

    @Test
    fun parsesCommentsJsonPayload() {
        val html = """
            <div>
              <input name="_token" value="csrf-comment">
              <input name="comment-user-id" value="42">
              <div id="comment-start">
                <div>
                  <img src="https://img.example/avatar.jpg">
                  <div class="comment-index-text">
                    <a>Alice</a>
                    <span>5分鐘前</span>
                  </div>
                  <div class="comment-index-text">Nice video</div>
                  <span class="report-btn" data-reportable-id="99" data-reportable-type="comment"></span>
                </div>
                <div id="comment-like-form-wrapper">
                  <input name="foreign_id" value="99">
                  <input name="is_positive" value="0">
                  <input name="comment-like-user-id" value="42">
                  <input name="comment-likes-count" value="3">
                  <input name="comment-likes-sum" value="3">
                  <input name="like-comment-status" value="0">
                  <input name="unlike-comment-status" value="0">
                  <span style="display:none">icon</span>
                  <span style="display:none">3</span>
                </div>
                <div id="reply-section-wrapper-99"></div>
                <div class="load-replies-btn">查看 2 則回覆</div>
              </div>
            </div>
        """.trimIndent()
        val json = JsonObject(mapOf("comments" to JsonPrimitive(html))).toString()

        val comments = parser.parseComments(json)

        assertEquals("csrf-comment", comments.csrfToken)
        assertEquals("42", comments.currentUserId)
        assertEquals(1, comments.comments.size)
        assertEquals("Alice", comments.comments.single().username)
        assertEquals("99", comments.comments.single().replyTargetIdOrNull)
        assertEquals("99", comments.comments.single().post.foreignId)
        assertEquals(3, comments.comments.single().thumbUp)
        assertEquals(3, comments.comments.single().post.commentLikesCount)
        assertEquals(3, comments.comments.single().post.commentLikesSum)
        assertEquals(2, comments.comments.single().replyCount)
        assertTrue(comments.comments.single().hasMoreReplies)
    }

    @Test
    fun parsesCommentRepliesJsonPayload() {
        val html = """
            <div id="reply-start-99">
              <div>
                <img src="https://img.example/reply-avatar.jpg">
                <div class="comment-index-text">
                  <a>Bob</a>
                  <span>1分鐘前</span>
                </div>
                <div class="comment-index-text">@Alice reply</div>
                <span class="report-btn" data-reportable-id="100" data-reportable-type="reply"></span>
              </div>
              <div>
                <input name="foreign_id" value="100">
                <input name="is_positive" value="1">
                <input name="comment-like-user-id" value="42">
                <input name="comment-likes-count" value="1">
                <input name="comment-likes-sum" value="1">
                <input name="like-comment-status" value="1">
                <input name="unlike-comment-status" value="0">
                <span style="display:none">icon</span>
                <span style="display:none">1</span>
              </div>
            </div>
        """.trimIndent()
        val json = JsonObject(mapOf("replies" to JsonPrimitive(html))).toString()

        val replies = parser.parseCommentReplies(json)

        assertEquals(1, replies.comments.size)
        assertEquals("Bob", replies.comments.single().username)
        assertTrue(replies.comments.single().isChildComment)
        assertEquals("100", replies.comments.single().post.foreignId)
        assertEquals(1, replies.comments.single().thumbUp)
        assertEquals(1, replies.comments.single().post.commentLikesCount)
        assertEquals(1, replies.comments.single().post.commentLikesSum)
        assertTrue(replies.comments.single().post.isPositive)
        assertTrue(replies.comments.single().post.likeCommentStatus)
    }

    @Test
    fun parsesCommentLikesFromHiddenInputsWithoutStyleSpans() {
        val html = """
            <div>
              <div id="comment-start">
                <div>
                  <img src="https://img.example/avatar.jpg">
                  <div class="comment-index-text">
                    <a>Alice</a>
                    <span>5分鐘前</span>
                  </div>
                  <div class="comment-index-text">Nice video</div>
                </div>
                <div id="comment-like-form-wrapper">
                  <input name="foreign_id" value="99">
                  <input name="comment-likes-count" value="7">
                  <input name="comment-likes-sum" value="5">
                  <span style="display:none">icon</span>
                  <span style="display:none">not-a-number</span>
                </div>
              </div>
            </div>
        """.trimIndent()
        val json = JsonObject(mapOf("comments" to JsonPrimitive(html))).toString()

        val comments = parser.parseComments(json)

        assertEquals(1, comments.comments.size)
        assertEquals(5, comments.comments.single().thumbUp)
        assertEquals(7, comments.comments.single().post.commentLikesCount)
        assertEquals(5, comments.comments.single().post.commentLikesSum)
    }

    @Test
    fun parseCommentsTreatsNonStringPayloadAsEmpty() {
        val json = JsonObject(mapOf("comments" to JsonObject(emptyMap()))).toString()

        val comments = parser.parseComments(json)

        assertEquals(0, comments.comments.size)
    }
}

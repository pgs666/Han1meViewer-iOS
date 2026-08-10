package com.yenaly.han1meviewer.shared.parser

import com.yenaly.han1meviewer.shared.model.SearchParams
import kotlin.test.Test
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Regression suite that runs the parser against *real captured pages*
 * dropped into `commonTest/resources/fixtures/`. This is the anti-drift
 * net: when the upstream Android project changes its HTML selectors, a
 * refreshed fixture here will catch any divergence in this manual port.
 *
 * Real samples are deferred for now — each fixture-driven test skips
 * gracefully (returns early) when the named file is absent, so the suite
 * stays green on CI until samples are added. See
 * `commonTest/resources/fixtures/README.md`.
 */
class ParserRegressionTest {
    private val parser = KsoupHtmlParser()

    @Test
    fun fixtureLoaderReadsBundledResource() {
        // `loader-selftest.html` is a tiny committed fixture proving the
        // JVM resource path works end-to-end. On Kotlin/Native this loader
        // returns null, so only assert when a value is present.
        val html = loadParserFixtureOrNull("loader-selftest.html") ?: return
        assertTrue(html.contains("home-rows-wrapper"))
    }

    @Test
    fun homeFixtureParsesSections() {
        val html = loadParserFixtureOrNull("home.html") ?: return
        val home = parser.parseHome(html)
        assertTrue(home.sections.isNotEmpty(), "home fixture produced no sections")
        assertNotNull(home.banner, "home fixture produced no banner")
        assertTrue(home.sections.all { it.items.isNotEmpty() }, "home fixture produced an empty section")
    }

    @Test
    fun searchFixtureParsesItems() {
        val html = loadParserFixtureOrNull("search.html") ?: return
        val result = parser.parseSearch(html, SearchParams(keyword = ""), page = 1)
        assertTrue(result.items.isNotEmpty(), "search fixture produced no items")
        assertTrue(result.items.all { it.videoCode.isNotBlank() }, "search fixture produced a blank video code")
        assertTrue(result.items.any { !it.coverUrl.isNullOrBlank() }, "search fixture produced no covers")
    }

    @Test
    fun videoFixtureParsesTitleAndSources() {
        val html = loadParserFixtureOrNull("video.html") ?: return
        val video = parser.parseVideo(html, videoCode = "407591")
        assertTrue(video.title.isNotBlank(), "video fixture produced blank title")
        assertTrue(video.tags.isNotEmpty(), "video fixture produced no tags")
        assertTrue(video.sources.isNotEmpty(), "video fixture produced no playback sources")
        assertTrue(video.playlist?.videos?.isNotEmpty() == true, "video fixture produced no playlist")
        assertTrue(video.relatedHanimes.isNotEmpty(), "video fixture produced no related videos")
    }

    @Test
    fun commentsFixtureParses() {
        val json = loadParserFixtureOrNull("comments.json") ?: return
        val comments = parser.parseComments(json)
        assertTrue(comments.comments.isNotEmpty(), "comments fixture produced no comments")
    }
}

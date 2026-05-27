package com.yenaly.han1meviewer.shared.session

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class SetCookieParserTest {
    @Test
    fun parsesBasicSetCookieHeader() {
        val cookie = SetCookieParser.parse(
            header = "hanime1_session=abc; Path=/; Domain=.hanime1.me; HttpOnly",
            fallbackDomain = "hanime1.me",
        )

        assertNotNull(cookie)
        assertEquals("hanime1_session", cookie.name)
        assertEquals("abc", cookie.value)
        assertEquals(".hanime1.me", cookie.domain)
        assertEquals("/", cookie.path)
        assertTrue(cookie.httpOnly)
    }

    @Test
    fun usesFallbackDomainWhenDomainAttributeIsMissing() {
        val cookie = SetCookieParser.parse(
            header = "XSRF-TOKEN=token; Path=/",
            fallbackDomain = "hanime1.me",
        )

        assertNotNull(cookie)
        assertEquals("hanime1.me", cookie.domain)
    }

    @Test
    fun parsesExpiresAndSecureAttributes() {
        val cookie = SetCookieParser.parse(
            header = "hanime1_session=abc; Path=/; Expires=Wed, 21 Oct 2037 07:28:00 GMT; Secure",
            fallbackDomain = "hanime1.me",
        )

        assertNotNull(cookie)
        assertTrue(cookie.secure)
        assertNotNull(cookie.expiresAtEpochMillis)
    }

    /**
     * iOS Darwin engine returns a single comma-joined string when the server sends
     * multiple `Set-Cookie` response headers (NSHTTPURLResponse merges duplicates).
     * Make sure parseAll splits them apart correctly without choking on the commas
     * inside `Expires` dates.
     */
    @Test
    fun parseAllSplitsMergedSetCookieHeaderFromDarwin() {
        val mergedSingleHeader = listOf(
            "XSRF-TOKEN=tok-xsrf; expires=Wed, 21 Oct 2037 07:28:00 GMT; Max-Age=7200; path=/, " +
                "hanime1_session=sess-abc; expires=Wed, 21 Oct 2037 07:28:00 GMT; Max-Age=7200; path=/; HttpOnly, " +
                "user_lang=zh-TW; path=/"
        )

        val cookies = SetCookieParser.parseAll(
            headers = mergedSingleHeader,
            fallbackDomain = "hanime1.me",
        )

        assertEquals(3, cookies.size, "expected 3 cookies parsed from merged header")
        val names = cookies.map { it.name }
        assertTrue("XSRF-TOKEN" in names)
        assertTrue("hanime1_session" in names)
        assertTrue("user_lang" in names)
        assertEquals("tok-xsrf", cookies.first { it.name == "XSRF-TOKEN" }.value)
        assertEquals("sess-abc", cookies.first { it.name == "hanime1_session" }.value)
        assertEquals("zh-TW", cookies.first { it.name == "user_lang" }.value)
        assertTrue(cookies.first { it.name == "hanime1_session" }.httpOnly)
    }

    @Test
    fun parseAllStillHandlesAlreadySeparateHeaders() {
        // Backwards compat: when the platform DOES expose Set-Cookie as multiple list
        // entries (JVM/OkHttp/..) the new logic must not break.
        val separate = listOf(
            "XSRF-TOKEN=tok; path=/",
            "hanime1_session=sess; path=/; HttpOnly",
        )

        val cookies = SetCookieParser.parseAll(
            headers = separate,
            fallbackDomain = "hanime1.me",
        )

        assertEquals(2, cookies.size)
    }
}

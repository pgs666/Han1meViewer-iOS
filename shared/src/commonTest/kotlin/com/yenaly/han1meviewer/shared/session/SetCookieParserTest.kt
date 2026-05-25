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
}

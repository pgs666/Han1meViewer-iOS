package com.yenaly.han1meviewer.shared.session

import com.yenaly.han1meviewer.shared.model.SessionCookie
import com.yenaly.han1meviewer.shared.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class CookieHeaderProviderTest {
    @Test
    fun buildsCookieHeaderForMatchingDomain() = runTest {
        val store = MemorySessionStore(
            listOf(
                SessionCookie(name = "session", value = "abc", domain = ".hanime1.me"),
                SessionCookie(name = "cf_clearance", value = "token", domain = "hanime1.me"),
                SessionCookie(name = "other", value = "ignored", domain = "example.com"),
            )
        )
        val provider = CookieHeaderProvider(store)

        assertEquals(
            "session=abc; cf_clearance=token",
            provider.buildCookieHeader("hanime1.me")
        )
    }

    @Test
    fun skipsExpiredCookies() = runTest {
        val store = MemorySessionStore(
            listOf(
                SessionCookie(
                    name = "expired",
                    value = "ignored",
                    domain = "hanime1.me",
                    expiresAtEpochMillis = 1L,
                )
            )
        )
        val provider = CookieHeaderProvider(store)

        assertNull(provider.buildCookieHeader("hanime1.me"))
    }

    @Test
    fun skipsSecureCookiesOnInsecureTransport() = runTest {
        val store = MemorySessionStore(
            listOf(
                SessionCookie(
                    name = "session",
                    value = "abc",
                    domain = "hanime1.me",
                    secure = true,
                )
            )
        )
        val provider = CookieHeaderProvider(store)

        assertNull(provider.buildCookieHeader("hanime1.me", isSecureTransport = false))
        assertEquals("session=abc", provider.buildCookieHeader("hanime1.me", isSecureTransport = true))
    }
}

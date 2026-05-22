package com.yenaly.han1meviewer.shared.auth

import com.yenaly.han1meviewer.shared.session.MemorySessionStore
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class WebLoginFeatureTest {
    @Test
    fun importsCookieHeaderIntoSessionStore() = runTest {
        val store = MemorySessionStore()
        val feature = WebLoginFeature(store)

        val snapshot = feature.importCookieHeader(
            cookieHeader = "XSRF-TOKEN=token; hanime1_session=session-value; cf_clearance=clearance",
            domain = "hanime1.me",
        )

        val cookies = store.loadCookies()
        assertTrue(snapshot.isLoggedIn)
        assertEquals(3, cookies.size)
        assertTrue(cookies.any { it.name == "hanime1_session" && it.value == "session-value" })
    }
}

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
        assertEquals(false, snapshot.isLoggedIn)
        assertEquals(3, cookies.size)
        assertTrue(cookies.any { it.name == "hanime1_session" && it.value == "session-value" })
    }

    @Test
    fun reportsCurrentLoginSession() = runTest {
        val store = MemorySessionStore()
        val feature = WebLoginFeature(store)

        assertEquals(false, feature.currentSessionSnapshot().isLoggedIn)

        feature.importConfirmedLoginCookieHeader(
            cookieHeader = "hanime1_session=session-value",
            domain = "hanime1.me",
        )

        assertEquals(true, feature.currentSessionSnapshot().isLoggedIn)
    }

    @Test
    fun logoutClearsCurrentLoginSession() = runTest {
        val store = MemorySessionStore()
        val feature = WebLoginFeature(store)

        feature.importConfirmedLoginCookieHeader(
            cookieHeader = "hanime1_session=session-value",
            domain = "hanime1.me",
        )

        val snapshot = feature.logout()

        assertEquals(false, snapshot.isLoggedIn)
        assertEquals(false, feature.currentSessionSnapshot().isLoggedIn)
        assertTrue(store.loadCookies().isEmpty())
    }

    @Test
    fun plainSessionCookieDoesNotReportLoggedIn() = runTest {
        val store = MemorySessionStore()
        val feature = WebLoginFeature(store)

        feature.importCookieHeader(
            cookieHeader = "hanime1_session=anonymous-session",
            domain = "hanime1.me",
        )

        assertEquals(false, feature.currentSessionSnapshot().isLoggedIn)
    }
}

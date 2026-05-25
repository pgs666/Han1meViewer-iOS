package com.yenaly.han1meviewer.shared.auth

import com.yenaly.han1meviewer.shared.model.HomePage
import com.yenaly.han1meviewer.shared.repository.HomeRepository
import com.yenaly.han1meviewer.shared.session.MemorySessionStore
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class WebLoginFeatureTest {
    @Test
    fun importsCookieHeaderIntoSessionStore() = runTest {
        val store = MemorySessionStore()
        val feature = WebLoginFeature(store, FakeHomeRepository.loggedIn())

        val snapshot = feature.importCookieHeader(
            cookieHeader = "XSRF-TOKEN=token; hanime1_session=session-value; cf_clearance=clearance",
            domain = "hanime1.me",
        )

        val cookies = store.loadCookies()
        assertEquals(true, snapshot.isLoggedIn)
        assertEquals(3, cookies.size)
        assertTrue(cookies.any { it.name == "hanime1_session" && it.value == "session-value" })
    }

    @Test
    fun reportsCurrentLoginSession() = runTest {
        val store = MemorySessionStore()
        val feature = WebLoginFeature(store, FakeHomeRepository.loggedIn())

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
        val feature = WebLoginFeature(store, FakeHomeRepository.loggedIn())

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
    fun importCookieHeaderRejectsInvalidSession() = runTest {
        val store = MemorySessionStore()
        val feature = WebLoginFeature(store, FakeHomeRepository.loggedOut())

        var threw = false
        try {
            feature.importCookieHeader(
                cookieHeader = "hanime1_session=anonymous-session",
                domain = "hanime1.me",
            )
        } catch (_: Exception) {
            threw = true
        }
        assertTrue(threw)
        assertTrue(store.loadCookies().isEmpty())
    }

    @Test
    fun confirmedImportDoesNotMarkLoggedInWhenHomeVerificationFails() = runTest {
        val store = MemorySessionStore()
        val feature = WebLoginFeature(store, FakeHomeRepository.loggedOut())

        val snapshot = feature.importConfirmedLoginCookieHeader(
            cookieHeader = "hanime1_session=session-value",
            domain = "hanime1.me",
        )

        assertEquals(false, snapshot.isLoggedIn)
        assertTrue(store.loadCookies().isEmpty())
    }

    @Test
    fun currentSessionClearsExpiredConfirmedMarker() = runTest {
        val store = MemorySessionStore()
        val repository = FakeHomeRepository.loggedIn()
        val feature = WebLoginFeature(store, repository)

        feature.importConfirmedLoginCookieHeader(
            cookieHeader = "hanime1_session=session-value",
            domain = "hanime1.me",
        )
        repository.homePage = homePage(userId = null, username = null)

        assertEquals(false, feature.currentSessionSnapshot().isLoggedIn)
        assertTrue(store.loadCookies().isEmpty())
    }

    @Test
    fun currentSessionKeepsCookiesWhenVerificationHasTransientError() = runTest {
        val store = MemorySessionStore()
        val repository = FakeHomeRepository.loggedIn()
        val feature = WebLoginFeature(store, repository)

        feature.importConfirmedLoginCookieHeader(
            cookieHeader = "hanime1_session=session-value",
            domain = "hanime1.me",
        )
        repository.error = RuntimeException("timeout")

        assertEquals(false, feature.currentSessionSnapshot().isLoggedIn)
        assertTrue(store.loadCookies().isNotEmpty())
    }

    private class FakeHomeRepository(
        var homePage: HomePage,
    ) : HomeRepository {
        var error: Exception? = null

        override suspend fun getHomePage(): HomePage {
            error?.let { throw it }
            return homePage
        }

        companion object {
            fun loggedIn(): FakeHomeRepository = FakeHomeRepository(homePage(userId = "123", username = "pgs"))

            fun loggedOut(): FakeHomeRepository = FakeHomeRepository(homePage(userId = null, username = null))
        }
    }

    private companion object {
        fun homePage(userId: String?, username: String?): HomePage {
            return HomePage(
                csrfToken = null,
                avatarUrl = null,
                username = username,
                banner = null,
                sections = emptyList(),
                userId = userId,
            )
        }
    }
}

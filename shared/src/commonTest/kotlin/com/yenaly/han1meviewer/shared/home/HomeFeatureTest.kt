package com.yenaly.han1meviewer.shared.home

import com.yenaly.han1meviewer.shared.auth.LoginSessionMarker
import com.yenaly.han1meviewer.shared.model.DomainError
import com.yenaly.han1meviewer.shared.model.DomainException
import com.yenaly.han1meviewer.shared.model.HomePage
import com.yenaly.han1meviewer.shared.repository.HomeRepository
import com.yenaly.han1meviewer.shared.session.MemorySessionStore
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class HomeFeatureTest {
    @Test
    fun loadHomeClearsExpiredConfirmedLoginSession() = runTest {
        val store = MemorySessionStore(listOf(LoginSessionMarker.cookie()))
        var didClearSession = false
        val feature = HomeFeature(
            repository = FakeHomeRepository(homePage(userId = null, username = null)),
            sessionStore = store,
            onSessionCleared = { didClearSession = true },
        )

        val error = assertFailsWith<DomainException> {
            feature.loadHome()
        }

        assertTrue(error.error is DomainError.Auth)
        assertTrue(store.loadCookies().isEmpty())
        assertEquals(true, didClearSession)
    }

    @Test
    fun loadHomeAllowsLoggedOutHomeWithoutConfirmedLoginSession() = runTest {
        val feature = HomeFeature(
            repository = FakeHomeRepository(homePage(userId = null, username = null)),
            sessionStore = MemorySessionStore(),
        )

        val snapshot = feature.loadHome()

        assertEquals(null, snapshot.username)
        assertEquals(0, snapshot.sectionCount)
    }

    @Test
    fun loadHomeKeepsConfirmedLoginWhenUserIsPresent() = runTest {
        val store = MemorySessionStore(listOf(LoginSessionMarker.cookie()))
        val feature = HomeFeature(
            repository = FakeHomeRepository(homePage(userId = "42", username = "Alice")),
            sessionStore = store,
        )

        val snapshot = feature.loadHome()

        assertEquals("Alice", snapshot.username)
        assertTrue(store.loadCookies().isNotEmpty())
    }

    private class FakeHomeRepository(
        private val homePage: HomePage,
    ) : HomeRepository {
        override suspend fun getHomePage(): HomePage = homePage
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

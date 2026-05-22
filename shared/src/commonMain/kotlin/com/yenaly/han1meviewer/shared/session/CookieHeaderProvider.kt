package com.yenaly.han1meviewer.shared.session

import com.yenaly.han1meviewer.shared.model.SessionCookie
import kotlin.time.Clock
import kotlin.time.ExperimentalTime

class CookieHeaderProvider(
    private val sessionStore: SessionStore,
) {
    suspend fun buildCookieHeader(domain: String): String? {
        val now = currentEpochMillis()
        val cookies = sessionStore.loadCookies()
            .filter { cookie -> cookie.matchesDomain(domain) }
            .filter { cookie -> cookie.expiresAtEpochMillis == null || cookie.expiresAtEpochMillis > now }

        if (cookies.isEmpty()) return null
        return cookies.joinToString(separator = "; ") { cookie -> "${cookie.name}=${cookie.value}" }
    }

    suspend fun saveResponseCookies(cookies: List<SessionCookie>) {
        if (cookies.isEmpty()) return
        sessionStore.saveCookies(cookies)
    }

    private fun SessionCookie.matchesDomain(requestDomain: String): Boolean {
        val normalizedRequestDomain = requestDomain.removePrefix(".")
        val normalizedCookieDomain = domain.removePrefix(".")
        return normalizedRequestDomain == normalizedCookieDomain ||
            normalizedRequestDomain.endsWith(".$normalizedCookieDomain")
    }

    @OptIn(ExperimentalTime::class)
    private fun currentEpochMillis(): Long = Clock.System.now().toEpochMilliseconds()
}

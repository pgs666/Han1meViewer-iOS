package com.yenaly.han1meviewer.shared.session

import com.yenaly.han1meviewer.shared.model.SessionCookie
import com.yenaly.han1meviewer.shared.util.currentEpochMillis

class CookieHeaderProvider(
    private val sessionStore: SessionStore,
) {
    suspend fun buildCookieHeader(domain: String, isSecureTransport: Boolean = true): String? {
        val now = currentEpochMillis()
        val cookies = sessionStore.loadCookies()
            .filter { cookie -> cookie.matchesDomain(domain) }
            .filter { cookie -> cookie.expiresAtEpochMillis == null || cookie.expiresAtEpochMillis > now }
            .filter { cookie -> !cookie.secure || isSecureTransport }

        if (cookies.isEmpty()) return null
        return cookies
            .sortedWith(compareByDescending<SessionCookie> { cookie -> cookie.path.length }
                .thenByDescending { cookie -> cookie.name }
                .thenByDescending { cookie -> cookie.domain.removePrefix(".") == domain.removePrefix(".") }
                .thenBy { cookie -> cookie.domain.startsWith(".") })
            .distinctBy { cookie -> cookie.name }
            .joinToString(separator = "; ") { cookie -> "${cookie.name}=${cookie.value}" }
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

}

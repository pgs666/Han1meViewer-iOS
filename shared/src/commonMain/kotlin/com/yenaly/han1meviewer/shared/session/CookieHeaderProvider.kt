package com.yenaly.han1meviewer.shared.session

import com.yenaly.han1meviewer.shared.model.SessionCookie
import com.yenaly.han1meviewer.shared.util.currentEpochMillis

class CookieHeaderProvider(
    private val sessionStore: SessionStore,
) {
    suspend fun buildCookieHeader(
        domain: String,
        requestPath: String = "/",
        isSecureTransport: Boolean = true,
        videoLanguage: String = "zht",
    ): String? {
        val now = currentEpochMillis()
        val storedCookies = sessionStore.loadCookies()
            .filter { cookie -> cookie.matchesDomain(domain) }
            .filter { cookie -> cookie.matchesPath(requestPath) }
            .filter { cookie -> cookie.expiresAtEpochMillis == null || cookie.expiresAtEpochMillis > now }
            .filter { cookie -> !cookie.secure || isSecureTransport }
        val prefCookies = preferencesCookies(domain, videoLanguage)
            .filter { pref -> storedCookies.none { it.name == pref.name } }
        val cookies = storedCookies + prefCookies

        if (cookies.isEmpty()) return null
        return cookies
            .sortedWith(compareByDescending<SessionCookie> { cookie -> cookie.path.length }
                .thenByDescending { cookie -> cookie.name }
                .thenByDescending { cookie -> cookie.domain.removePrefix(".") == domain.removePrefix(".") }
                .thenBy { cookie -> cookie.domain.startsWith(".") })
            .distinctBy { cookie -> cookie.name }
            .joinToString(separator = "; ") { cookie -> "${cookie.name}=${cookie.value}" }
    }

    /**
     * Returns preference cookies that should be sent with every request.
     * These persist across login/logout (like Android's preferencesCookieList).
     * The video language defaults to the device locale and can be overridden via settings.
     */
    fun preferencesCookies(domain: String, videoLanguage: String = "zht"): List<SessionCookie> {
        return listOf(
            SessionCookie(
                name = "user_lang",
                value = videoLanguage,
                domain = domain,
            )
        )
    }

    suspend fun saveResponseCookies(cookies: List<SessionCookie>) {
        if (cookies.isEmpty()) return
        sessionStore.saveCookies(cookies)
    }

    private fun SessionCookie.matchesPath(requestPath: String): Boolean {
        val cookiePath = path.ifEmpty { "/" }
        if (cookiePath == "/") return true
        if (requestPath == cookiePath) return true
        if (requestPath.startsWith(cookiePath) &&
            (requestPath[cookiePath.length] == '/' || cookiePath.endsWith("/"))) {
            return true
        }
        return false
    }

    private fun SessionCookie.matchesDomain(requestDomain: String): Boolean {
        val normalizedRequestDomain = requestDomain.removePrefix(".")
        val normalizedCookieDomain = domain.removePrefix(".")
        return normalizedRequestDomain == normalizedCookieDomain ||
            normalizedRequestDomain.endsWith(".$normalizedCookieDomain")
    }

}

package com.yenaly.han1meviewer.shared.auth

import com.yenaly.han1meviewer.shared.model.SessionCookie
import com.yenaly.han1meviewer.shared.repository.AuthRepository
import com.yenaly.han1meviewer.shared.session.SessionStore
import kotlinx.serialization.Serializable

class AuthFeature(
    private val repository: AuthRepository,
) {
    suspend fun login(email: String, password: String): AuthSnapshot {
        val result = repository.login(email, password)
        return AuthSnapshot(
            isLoggedIn = result.isLoggedIn,
            message = if (result.isLoggedIn) {
                "Login succeeded"
            } else {
                "Login failed. Check your email, password, or Cloudflare state."
            },
            username = result.username,
        )
    }
}

class WebLoginFeature(
    private val sessionStore: SessionStore,
) {
    suspend fun importCookieHeader(cookieHeader: String, domain: String): AuthSnapshot {
        val cookies = parseCookieHeader(cookieHeader, domain)

        sessionStore.saveCookies(cookies)

        return AuthSnapshot(
            isLoggedIn = false,
            message = "Web cookies imported but login was not confirmed.",
            username = null,
        )
    }

    suspend fun importConfirmedLoginCookieHeader(cookieHeader: String, domain: String): AuthSnapshot {
        val cookies = parseCookieHeader(cookieHeader, domain) + SessionCookie(
            name = confirmedLoginCookieName,
            value = "true",
            domain = appCookieDomain,
        )

        sessionStore.saveCookies(cookies)

        return AuthSnapshot(
            isLoggedIn = true,
            message = "Web login confirmed",
            username = null,
        )
    }

    suspend fun currentSessionSnapshot(): AuthSnapshot {
        val isLoggedIn = sessionStore.loadCookies().hasLoginSession()
        return AuthSnapshot(
            isLoggedIn = isLoggedIn,
            message = if (isLoggedIn) {
                "Login session found"
            } else {
                "No login session found"
            },
            username = null,
        )
    }

    suspend fun logout(): AuthSnapshot {
        sessionStore.clear()
        return AuthSnapshot(
            isLoggedIn = false,
            message = "Logged out",
            username = null,
        )
    }

    private fun List<SessionCookie>.hasLoginSession(): Boolean {
        return any { cookie ->
            cookie.name == confirmedLoginCookieName &&
                cookie.value == "true" &&
                cookie.domain == appCookieDomain
        }
    }

    private fun parseCookieHeader(cookieHeader: String, domain: String): List<SessionCookie> {
        return cookieHeader.split(";")
            .mapNotNull { rawCookie ->
                val parts = rawCookie.trim().split("=", limit = 2)
                val name = parts.getOrNull(0)?.trim().orEmpty()
                val value = parts.getOrNull(1)?.trim().orEmpty()
                if (name.isBlank() || value.isBlank()) {
                    null
                } else {
                    SessionCookie(
                        name = name,
                        value = value,
                        domain = domain,
                    )
                }
            }
    }

    private companion object {
        const val confirmedLoginCookieName = "han1me_ios_web_login_confirmed"
        const val appCookieDomain = "han1meviewer.local"
    }
}

@Serializable
data class AuthSnapshot(
    val isLoggedIn: Boolean,
    val message: String,
    val username: String?,
)

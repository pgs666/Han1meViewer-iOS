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
        val cookies = cookieHeader.split(";")
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

        sessionStore.saveCookies(cookies)

        val isLoggedIn = cookies.any { cookie ->
            cookie.name.equals("hanime1_session", ignoreCase = true) ||
                cookie.name.contains("session", ignoreCase = true)
        }

        return AuthSnapshot(
            isLoggedIn = isLoggedIn,
            message = if (isLoggedIn) {
                "Web login cookie imported"
            } else {
                "Cookies imported, but no login session cookie was found."
            },
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

    private fun List<SessionCookie>.hasLoginSession(): Boolean {
        return any { cookie ->
            cookie.name.equals("hanime1_session", ignoreCase = true) ||
                cookie.name.contains("session", ignoreCase = true)
        }
    }
}

@Serializable
data class AuthSnapshot(
    val isLoggedIn: Boolean,
    val message: String,
    val username: String?,
)

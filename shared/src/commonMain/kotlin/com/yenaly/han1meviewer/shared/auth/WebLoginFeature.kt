package com.yenaly.han1meviewer.shared.auth

import com.yenaly.han1meviewer.shared.model.SessionCookie
import com.yenaly.han1meviewer.shared.repository.HomeRepository
import com.yenaly.han1meviewer.shared.session.SessionStore
import kotlinx.serialization.Serializable

class WebLoginFeature(
    private val sessionStore: SessionStore,
    private val homeRepository: HomeRepository,
) {
    @Throws(Exception::class)
    suspend fun importCookieHeader(cookieHeader: String, domain: String): AuthSnapshot {
        val cookies = parseCookieHeader(cookieHeader, domain)

        sessionStore.saveCookies(cookies)

        return AuthSnapshot(
            isLoggedIn = false,
            message = "Web cookies imported but login was not confirmed.",
            username = null,
        )
    }

    @Throws(Exception::class)
    suspend fun importConfirmedLoginCookieHeader(cookieHeader: String, domain: String): AuthSnapshot {
        sessionStore.saveCookies(parseCookieHeader(cookieHeader, domain))
        val snapshot = try {
            verifyCurrentSession()
        } catch (error: Throwable) {
            sessionStore.clear()
            throw error
        }
        if (!snapshot.isLoggedIn) {
            sessionStore.clear()
            return snapshot
        }
        sessionStore.saveCookies(
            sessionStore.loadCookies() + SessionCookie(
                name = confirmedLoginCookieName,
                value = "true",
                domain = appCookieDomain,
            )
        )

        return AuthSnapshot(
            isLoggedIn = true,
            message = "Web login confirmed",
            username = snapshot.username,
        )
    }

    @Throws(Exception::class)
    suspend fun currentSessionSnapshot(): AuthSnapshot {
        if (!sessionStore.loadCookies().hasLoginSession()) {
            return AuthSnapshot(
                isLoggedIn = false,
                message = "No login session found",
                username = null,
            )
        }

        return try {
            val snapshot = verifyCurrentSession()
            if (!snapshot.isLoggedIn) {
                sessionStore.clear()
            }
            snapshot
        } catch (error: Throwable) {
            sessionStore.clear()
            AuthSnapshot(
                isLoggedIn = false,
                message = error.message ?: "Login session could not be verified",
                username = null,
            )
        }
    }

    @Throws(Exception::class)
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

    private suspend fun verifyCurrentSession(): AuthSnapshot {
        val homePage = homeRepository.getHomePage()
        val isLoggedIn = !homePage.userId.isNullOrBlank() || !homePage.username.isNullOrBlank()
        return AuthSnapshot(
            isLoggedIn = isLoggedIn,
            message = if (isLoggedIn) {
                "Login session verified"
            } else {
                "Login session expired"
            },
            username = homePage.username,
        )
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

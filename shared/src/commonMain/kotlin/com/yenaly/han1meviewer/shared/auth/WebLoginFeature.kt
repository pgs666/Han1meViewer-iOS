package com.yenaly.han1meviewer.shared.auth

import com.yenaly.han1meviewer.shared.auth.LoginSessionMarker.hasConfirmedLogin
import com.yenaly.han1meviewer.shared.model.DomainError
import com.yenaly.han1meviewer.shared.model.DomainException
import com.yenaly.han1meviewer.shared.model.SessionCookie
import com.yenaly.han1meviewer.shared.repository.HomeRepository
import com.yenaly.han1meviewer.shared.session.SessionStore
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.Serializable

class WebLoginFeature(
    private val sessionStore: SessionStore,
    private val homeRepository: HomeRepository,
    private val onSessionCleared: () -> Unit = {},
) {
    @Throws(Exception::class)
    suspend fun importCookieHeader(cookieHeader: String, domain: String): AuthSnapshot {
        val cookies = parseCookieHeader(cookieHeader, domain)
        sessionStore.saveCookies(cookies)

        val snapshot = try {
            verifyCurrentSession()
        } catch (error: Exception) {
            if (error is CancellationException) throw error
            clearSession()
            throw error
        }
        if (!snapshot.isLoggedIn) {
            clearSession()
            throw DomainException(DomainError.Auth("Imported cookies did not produce a valid session."))
        }
        return snapshot
    }

    @Throws(Exception::class)
    suspend fun importConfirmedLoginCookieHeader(cookieHeader: String, domain: String): AuthSnapshot {
        sessionStore.saveCookies(parseCookieHeader(cookieHeader, domain))
        val snapshot = try {
            verifyCurrentSession()
        } catch (error: Exception) {
            if (error is CancellationException) throw error
            if (error.shouldClearSession()) {
                clearSession()
            }
            throw error
        }
        if (!snapshot.isLoggedIn) {
            clearSession()
            return snapshot
        }
        sessionStore.saveCookies(
            sessionStore.loadCookies() + LoginSessionMarker.cookie()
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
                clearSession()
            }
            snapshot
        } catch (error: Exception) {
            if (error is CancellationException) throw error
            if (error.shouldClearSession()) {
                clearSession()
            }
            AuthSnapshot(
                isLoggedIn = false,
                message = error.message ?: "Login session could not be verified",
                username = null,
            )
        }
    }

    @Throws(Exception::class)
    suspend fun logout(): AuthSnapshot {
        clearSession()
        return AuthSnapshot(
            isLoggedIn = false,
            message = "Logged out",
            username = null,
        )
    }

    private fun List<SessionCookie>.hasLoginSession(): Boolean {
        return hasConfirmedLogin()
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

    private suspend fun clearSession() {
        sessionStore.clear()
        onSessionCleared()
    }

    private fun Exception.shouldClearSession(): Boolean {
        val domainError = (this as? DomainException)?.error ?: return false
        return when (domainError) {
            is DomainError.Auth -> true
            is DomainError.Network -> domainError.statusCode == 401 || domainError.statusCode == 403
            is DomainError.CloudflareBlocked,
            is DomainError.Parse,
            is DomainError.Unknown -> false
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
                        secure = true,
                    )
                }
            }
    }

}

@Serializable
data class AuthSnapshot(
    val isLoggedIn: Boolean,
    val message: String,
    val username: String?,
)

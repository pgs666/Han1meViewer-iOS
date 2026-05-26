package com.yenaly.han1meviewer.shared.auth

import com.yenaly.han1meviewer.shared.auth.LoginSessionMarker.hasConfirmedLogin
import com.yenaly.han1meviewer.shared.model.DomainError
import com.yenaly.han1meviewer.shared.model.DomainException
import com.yenaly.han1meviewer.shared.model.SessionCookie
import com.yenaly.han1meviewer.shared.repository.HomeRepository
import com.yenaly.han1meviewer.shared.session.SessionStore
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

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
            // Do not clear session on transient parse failures.
            throw error
        }
        if (!snapshot.isLoggedIn) {
            throw DomainException(DomainError.Auth("Imported cookies did not produce a valid session."))
        }
        return snapshot
    }

    @Throws(Exception::class)
    suspend fun importConfirmedLoginCookieHeader(cookieHeader: String, domain: String): AuthSnapshot {
        return importConfirmedLoginCookies(parseCookieHeader(cookieHeader, domain))
    }

    @Throws(Exception::class)
    suspend fun importConfirmedLoginCookiesJson(cookieJson: String, fallbackDomain: String): AuthSnapshot {
        val cookies = Json.decodeFromString<List<WebCookiePayload>>(cookieJson)
            .mapNotNull { it.toSessionCookie(fallbackDomain) }
        return importConfirmedLoginCookies(cookies)
    }

    private suspend fun importConfirmedLoginCookies(cookies: List<SessionCookie>): AuthSnapshot {
        sessionStore.clearLoginCookies()
        sessionStore.saveCookies(cookies)
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
        val isLoggedIn = !homePage.userId.isNullOrBlank()
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
        sessionStore.clearLoginCookies()
        onSessionCleared()
    }

    private fun Exception.shouldClearSession(): Boolean {
        val domainError = (this as? DomainException)?.error ?: return false
        return when (domainError) {
            is DomainError.Auth -> true
            is DomainError.Network -> domainError.statusCode == 401
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
internal data class WebCookiePayload(
    val name: String,
    val value: String,
    val domain: String? = null,
    val path: String? = null,
    val expiresAtEpochMillis: Long? = null,
    val secure: Boolean = false,
    val httpOnly: Boolean = false,
) {
    fun toSessionCookie(fallbackDomain: String): SessionCookie? {
        val trimmedName = name.trim()
        val trimmedValue = value.trim()
        if (trimmedName.isBlank() || trimmedValue.isBlank()) {
            return null
        }
        return SessionCookie(
            name = trimmedName,
            value = trimmedValue,
            domain = domain?.takeIf { it.isNotBlank() } ?: fallbackDomain,
            path = path?.takeIf { it.isNotBlank() } ?: "/",
            expiresAtEpochMillis = expiresAtEpochMillis,
            secure = secure,
            httpOnly = httpOnly,
        )
    }
}

@Serializable
data class AuthSnapshot(
    val isLoggedIn: Boolean,
    val message: String,
    val username: String?,
)
